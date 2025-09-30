import SwiftUI
import MapKit
import CoreLocation

// MARK: - Geofence Creation View
struct CreateGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var geofenceService = GeofenceService()
    @StateObject private var locationManager = LocationManager()
    
    let familyId: String
    let existingGeofence: Geofence?
    
    @State private var geofenceName = ""
    @State private var selectedRadius: Double = 100
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showingLocationPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let radiusOptions: [Double] = [50, 100, 200, 500, 1000]
    
    init(familyId: String, existingGeofence: Geofence? = nil) {
        self.familyId = familyId
        self.existingGeofence = existingGeofence
        
        // Initialize state with existing geofence data if editing
        if let geofence = existingGeofence {
            self._geofenceName = State(initialValue: geofence.name)
            self._selectedRadius = State(initialValue: geofence.radius)
            self._selectedCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude))
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(existingGeofence != nil ? "Edit Location Alert" : "Create Location Alert")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Family Location Alert")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Location Alert Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Alert Name")
                        .font(.headline)
                    
                    TextField("e.g., School, Home, Park", text: $geofenceName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Radius Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Radius")
                        .font(.headline)
                    
                    HStack {
                        Slider(value: $selectedRadius, in: 50...1000, step: 50)
                            .accentColor(.blue)
                        
                        Text("\(Int(selectedRadius))m")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60)
                    }
                    
                    // Quick radius buttons
                    HStack(spacing: 12) {
                        ForEach(radiusOptions, id: \.self) { radius in
                            Button(action: {
                                selectedRadius = radius
                            }) {
                                Text("\(Int(radius))m")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedRadius == radius ? Color.blue : Color.gray.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedRadius == radius ? .white : .primary
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Location Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                    
                    if let coordinate = selectedCoordinate {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading) {
                                Text("Lat: \(coordinate.latitude, specifier: "%.6f")")
                                    .font(.caption)
                                Text("Lng: \(coordinate.longitude, specifier: "%.6f")")
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingLocationPicker = true
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            showingLocationPicker = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Select Location")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Preview Map
                if let coordinate = selectedCoordinate {
                    GeofencePreviewMap(
                        coordinate: coordinate,
                        radius: selectedRadius,
                        geofenceName: geofenceName.isEmpty ? "New Location Alert" : geofenceName,
                        isInteractive: existingGeofence == nil
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                // Create Button
                Button(action: createGeofence) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text(existingGeofence != nil ? "Update Location Alert" : "Create Location Alert")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        canCreateGeofence ? Color.blue : Color.gray
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canCreateGeofence || isLoading)
            }
            .padding()
            .navigationTitle("New Location Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedCoordinate: $selectedCoordinate)
            }
        }
    }
    
    private var canCreateGeofence: Bool {
        !geofenceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCoordinate != nil
    }
    
    private func createGeofence() {
        guard let coordinate = selectedCoordinate else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if let existingGeofence = existingGeofence {
                    // Update existing geofence
                    try await geofenceService.updateGeofence(
                        geofence: existingGeofence,
                        name: geofenceName.trimmingCharacters(in: .whitespacesAndNewlines),
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        radius: selectedRadius
                    )
                } else {
                    // Create new geofence
                    try await geofenceService.createGeofence(
                        familyId: familyId,
                        name: geofenceName.trimmingCharacters(in: .whitespacesAndNewlines),
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        radius: selectedRadius
                    )
                }
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchDelegate = SearchCompleterDelegate()
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var region: MKCoordinateRegion
    
    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>) {
        self._selectedCoordinate = selectedCoordinate
        
        // Initialize region with existing coordinate or default location
        let center = selectedCoordinate.wrappedValue ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        self._region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    @State private var searchText = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var showingSearchResults = false
    @State private var isSelectingLocation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search for a location...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchText) { newValue in
                                if newValue.count > 2 {
                                    searchCompleter.queryFragment = newValue
                                } else {
                                    searchResults = []
                                    showingSearchResults = false
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                searchResults = []
                                showingSearchResults = false
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Search Results
                    if showingSearchResults && !searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { result in
                                    SearchResultRow(result: result) {
                                        performSearch(for: result)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                }
                .background(Color(.systemBackground))
                
                // Map
                Map(coordinateRegion: $region, annotationItems: [MapPinAnnotation(coordinate: region.center)]) { annotation in
                    MapPin(coordinate: annotation.coordinate, tint: .red)
                }
                .onTapGesture {
                    // Use the center of the current region as the selected coordinate
                    selectedCoordinate = region.center
                }
                .onChange(of: region.center.latitude) { _ in
                    selectedCoordinate = region.center
                }
                .onChange(of: region.center.longitude) { _ in
                    selectedCoordinate = region.center
                }
                
                VStack(spacing: 16) {
                    Text("Tap on the map to select location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let coordinate = selectedCoordinate {
                        VStack(spacing: 4) {
                            Text("Selected Location")
                                .font(.headline)
                            Text("Lat: \(coordinate.latitude, specifier: "%.6f")")
                                .font(.caption)
                            Text("Lng: \(coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Done") {
                    dismiss()
                }
                .disabled(selectedCoordinate == nil)
            )
            .onAppear {
                if let userLocation = locationManager.location {
                    region.center = userLocation.coordinate
                }
                setupSearchCompleter()
            }
        }
    }
    
    private func setupSearchCompleter() {
        searchCompleter.delegate = searchDelegate
        searchCompleter.resultTypes = [MKLocalSearchCompleter.ResultType.address, MKLocalSearchCompleter.ResultType.pointOfInterest]
        
        searchDelegate.onResultsUpdate = { (results: [MKLocalSearchCompletion]) in
            // Don't update if we're in the middle of selecting a location
            guard !isSelectingLocation else { return }
            
            searchResults = results
            showingSearchResults = !results.isEmpty
        }
    }
    
    private func performSearch(for completion: MKLocalSearchCompletion) {
        // Set flag to prevent delegate from interfering
        isSelectingLocation = true
        
        // Immediately close the dropdown
        showingSearchResults = false
        searchResults = []
        
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let mapItem = response.mapItems.first else {
                DispatchQueue.main.async {
                    isSelectingLocation = false
                }
                return
            }
            
            DispatchQueue.main.async {
                let coordinate = mapItem.placemark.coordinate
                region.center = coordinate
                selectedCoordinate = coordinate
                searchText = completion.title
                
                // Reset flag after selection is complete
                isSelectingLocation = false
            }
        }
    }
}

// MARK: - Search Completer Delegate
class SearchCompleterDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    var onResultsUpdate: (([MKLocalSearchCompletion]) -> Void)?
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.onResultsUpdate?(completer.results)
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer failed: \(error.localizedDescription)")
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: MKLocalSearchCompletion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemBackground))
        
        Divider()
            .padding(.leading, 16)
    }
}

// MARK: - Geofence Preview Map
struct GeofencePreviewMap: View {
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let geofenceName: String
    let isInteractive: Bool
    
    init(coordinate: CLLocationCoordinate2D, radius: Double, geofenceName: String, isInteractive: Bool = true) {
        self.coordinate = coordinate
        self.radius = radius
        self.geofenceName = geofenceName
        self.isInteractive = isInteractive
    }
    
    var body: some View {
        Map(coordinateRegion: .constant(calculateRegion()), annotationItems: [GeofenceAnnotation(coordinate: coordinate, name: geofenceName)]) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                VStack {
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: CGFloat(radius / 10), height: CGFloat(radius / 10))
                        .opacity(0.6)
                    
                    Text(annotation.name)
                        .font(.caption)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(4)
                        .shadow(radius: 2)
                }
            }
        }
        .allowsHitTesting(isInteractive)
    }
    
    private func calculateRegion() -> MKCoordinateRegion {
        // Calculate appropriate span based on radius
        let span = max(radius / 111000, 0.001) // Convert meters to degrees (roughly)
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span * 2, longitudeDelta: span * 2)
        )
    }
}

// MARK: - Map Annotations
struct GeofenceAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
}

struct MapPinAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
}
