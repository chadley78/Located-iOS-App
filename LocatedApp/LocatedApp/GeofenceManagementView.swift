import SwiftUI
import MapKit

// MARK: - Type Aliases
typealias EditGeofenceView = CreateGeofenceView

// MARK: - Geofence Management View
struct GeofenceManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationService: LocationService
    @StateObject private var geofenceService = GeofenceService()
    
    let familyId: String
    
    @State private var showingCreateGeofence = false
    @State private var selectedGeofence: Geofence?
    @State private var showingGeofenceDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                if geofenceService.isLoading {
                    ProgressView("Loading location alerts...")
                        .font(.radioCanadaBig(16, weight: .regular))
                        .padding(.top, 60)
                    Spacer()
                } else if geofenceService.geofences.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image("CreateFamily")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 120)
                            .padding(.top, 60)
                        
                        VStack(spacing: 8) {
                            Text("No Location Alerts Yet")
                                .font(.radioCanadaBig(20, weight: .semibold))
                            
                            Text("Create your first location alert to get notified when family members enter or leave specific areas.")
                                .font(.radioCanadaBig(14, weight: .regular))
                                .foregroundColor(.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            showingCreateGeofence = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create First Location Alert")
                            }
                        }
                        .primaryAButtonStyle()
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                } else {
                    // Location Alerts List
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
                        .padding(.top, 20)
                    }
                    
                    // Add Location Alert Button
                    Button(action: {
                        showingCreateGeofence = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Location Alert")
                        }
                    }
                    .primaryAButtonStyle()
                    .padding()
                }
            }
            .background(Color.vibrantYellow)
            .navigationTitle("Location Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await geofenceService.fetchGeofences(for: familyId)
                }
            }
            .sheet(isPresented: $showingCreateGeofence) {
                CreateGeofenceView(familyId: familyId)
                    .environmentObject(locationService)
                    .onDisappear {
                        Task {
                            await geofenceService.fetchGeofences(for: familyId)
                        }
                    }
            }
            .sheet(isPresented: $showingGeofenceDetails) {
                if let geofence = selectedGeofence {
                    EditGeofenceView(familyId: familyId, existingGeofence: geofence)
                        .environmentObject(locationService)
                        .onDisappear {
                            Task {
                                await geofenceService.fetchGeofences(for: familyId)
                            }
                        }
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name)
                        .font(.radioCanadaBig(18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(Int(geofence.radius))m radius")
                        .font(.radioCanadaBig(12, weight: .regular))
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
                        .font(.radioCanadaBig(10, weight: .regular))
                        .foregroundColor(.secondary)
                    Text("Lng: \(geofence.longitude, specifier: "%.6f")")
                        .font(.radioCanadaBig(10, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Mini map preview
            GeofencePreviewMap(
                coordinate: CLLocationCoordinate2D(
                    latitude: geofence.latitude,
                    longitude: geofence.longitude
                ),
                radius: geofence.radius,
                geofenceName: geofence.name,
                isInteractive: false
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
                    .font(.radioCanadaBig(12, weight: .regular))
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
                    .font(.radioCanadaBig(12, weight: .regular))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
            }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
        .background(Color(red: 1.0, green: 0.95, blue: 0.78)) // #FFF3C7
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .alert("Delete Location Alert", isPresented: $showingDeleteAlert) {
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
                        Text("Location Alert Details")
                            .font(.radioCanadaBig(22, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Name", value: geofence.name)
                            DetailRow(title: "Radius", value: "\(Int(geofence.radius)) meters")
                            DetailRow(title: "Status", value: geofence.isActive ? "Active" : "Inactive")
                            DetailRow(title: "Created", value: geofence.createdAt.formatted(date: .abbreviated, time: .shortened))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Location")
                                    .font(.radioCanadaBig(18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Latitude: \(geofence.latitude, specifier: "%.6f")")
                                    .font(.radioCanadaBig(12, weight: .regular))
                                    .foregroundColor(.secondary)
                                Text("Longitude: \(geofence.longitude, specifier: "%.6f")")
                                    .font(.radioCanadaBig(12, weight: .regular))
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
                        geofenceName: geofence.name,
                        isInteractive: false
                    )
                    .frame(height: 250)
                    .cornerRadius(12)
                    
                    // Events Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Events")
                                .font(.radioCanadaBig(18, weight: .semibold))
                            
                            Spacer()
                            
                            Button("View All") {
                                showingEvents = true
                            }
                            .font(.radioCanadaBig(12, weight: .regular))
                            .foregroundColor(.blue)
                        }
                        
                        if geofenceService.geofenceEvents.isEmpty {
                            Text("No events yet")
                                .font(.radioCanadaBig(14, weight: .regular))
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
                    await geofenceService.fetchGeofenceEvents(for: geofence.familyId)
                }
            }
            .sheet(isPresented: $showingEvents) {
                GeofenceEventsView(familyId: geofence.familyId, geofenceName: geofence.name)
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
                .font(.radioCanadaBig(16, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.radioCanadaBig(14, weight: .regular))
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
                    .font(.radioCanadaBig(14, weight: .medium))
                
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.radioCanadaBig(12, weight: .regular))
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
    
    let familyId: String
    let geofenceName: String
    
    var body: some View {
        NavigationView {
            VStack {
                if geofenceService.isLoading {
                    Spacer()
                    ProgressView("Loading events...")
                        .font(.radioCanadaBig(16, weight: .regular))
                    Spacer()
                } else if geofenceService.geofenceEvents.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Events Yet")
                            .font(.radioCanadaBig(20, weight: .semibold))
                        
                        Text("Events will appear here when family members enter or leave the '\(geofenceName)' geofence.")
                            .font(.radioCanadaBig(14, weight: .regular))
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
            .navigationTitle("Location Alert Events")
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
                    await geofenceService.fetchGeofenceEvents(for: familyId)
                }
            }
        }
    }
}
