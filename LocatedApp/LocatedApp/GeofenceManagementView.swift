import SwiftUI
import MapKit

// MARK: - Geofence Management View
struct GeofenceManagementView: View {
    @StateObject private var geofenceService = GeofenceService()
    @StateObject private var childLocationService = ChildLocationService()
    
    let childId: String
    let childName: String
    
    @State private var showingCreateGeofence = false
    @State private var selectedGeofence: Geofence?
    @State private var showingGeofenceDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Geofences")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("For \(childName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                if geofenceService.isLoading {
                    Spacer()
                    ProgressView("Loading geofences...")
                    Spacer()
                } else if geofenceService.geofences.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "location.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("No Geofences Yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Create your first geofence to get notified when \(childName) enters or leaves specific areas.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingCreateGeofence = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create First Geofence")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // Geofences List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(geofenceService.geofences) { geofence in
                                GeofenceCard(
                                    geofence: geofence,
                                    onTap: {
                                        selectedGeofence = geofence
                                        showingGeofenceDetails = true
                                    },
                                    onDelete: {
                                        Task {
                                            try? await geofenceService.deleteGeofence(geofence)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    
                    // Add Geofence Button
                    Button(action: {
                        showingCreateGeofence = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Geofence")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Geofences")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await geofenceService.fetchGeofences(for: childId)
                }
            }
            .sheet(isPresented: $showingCreateGeofence) {
                CreateGeofenceView(childId: childId, childName: childName)
                    .onDisappear {
                        Task {
                            await geofenceService.fetchGeofences(for: childId)
                        }
                    }
            }
            .sheet(isPresented: $showingGeofenceDetails) {
                if let geofence = selectedGeofence {
                    GeofenceDetailsView(geofence: geofence)
                }
            }
        }
    }
}

// MARK: - Geofence Card
struct GeofenceCard: View {
    let geofence: Geofence
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(geofence.radius))m radius")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(geofence.isActive ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
            }
            
            // Location info
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lat: \(geofence.latitude, specifier: "%.6f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Lng: \(geofence.longitude, specifier: "%.6f")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Created date
                Text(geofence.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Mini map preview
            GeofencePreviewMap(
                coordinate: CLLocationCoordinate2D(
                    latitude: geofence.latitude,
                    longitude: geofence.longitude
                ),
                radius: geofence.radius,
                geofenceName: geofence.name
            )
            .frame(height: 120)
            .cornerRadius(8)
            
            // Actions
            HStack {
                Button(action: onTap) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Details")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .alert("Delete Geofence", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(geofence.name)'? This action cannot be undone.")
        }
    }
}

// MARK: - Geofence Details View
struct GeofenceDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var geofenceService = GeofenceService()
    
    let geofence: Geofence
    
    @State private var showingEvents = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Geofence Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Geofence Details")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Name", value: geofence.name)
                            DetailRow(title: "Radius", value: "\(Int(geofence.radius)) meters")
                            DetailRow(title: "Status", value: geofence.isActive ? "Active" : "Inactive")
                            DetailRow(title: "Created", value: geofence.createdAt.formatted(date: .abbreviated, time: .shortened))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Latitude: \(geofence.latitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Longitude: \(geofence.longitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Map View
                    GeofencePreviewMap(
                        coordinate: CLLocationCoordinate2D(
                            latitude: geofence.latitude,
                            longitude: geofence.longitude
                        ),
                        radius: geofence.radius,
                        geofenceName: geofence.name
                    )
                    .frame(height: 250)
                    .cornerRadius(12)
                    
                    // Events Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Events")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("View All") {
                                showingEvents = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        if geofenceService.geofenceEvents.isEmpty {
                            Text("No events yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(geofenceService.geofenceEvents.prefix(3)) { event in
                                EventRow(event: event)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .padding()
            }
            .navigationTitle(geofence.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await geofenceService.fetchGeofenceEvents(for: geofence.childId)
                }
            }
            .sheet(isPresented: $showingEvents) {
                GeofenceEventsView(childId: geofence.childId, childName: geofence.name)
            }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Event Row
struct EventRow: View {
    let event: GeofenceEvent
    
    var body: some View {
        HStack {
            // Event type icon
            Image(systemName: event.eventType == .enter ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(event.eventType == .enter ? .green : .orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.eventType.displayName + " " + event.geofenceName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Geofence Events View
struct GeofenceEventsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var geofenceService = GeofenceService()
    
    let childId: String
    let childName: String
    
    var body: some View {
        NavigationView {
            VStack {
                if geofenceService.isLoading {
                    Spacer()
                    ProgressView("Loading events...")
                    Spacer()
                } else if geofenceService.geofenceEvents.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Events Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Events will appear here when \(childName) enters or leaves geofenced areas.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    List(geofenceService.geofenceEvents) { event in
                        EventRow(event: event)
                    }
                }
            }
            .navigationTitle("Geofence Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await geofenceService.fetchGeofenceEvents(for: childId)
                }
            }
        }
    }
}
