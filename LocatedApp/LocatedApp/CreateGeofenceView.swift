import SwiftUI
import MapKit
import CoreLocation

// MARK: - Geofence Creation View
struct CreateGeofenceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationService: LocationService
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
        CustomNavigationContainer(
            title: "New Location Alert",
            backgroundColor: AppColors.background,
            leadingButton: CustomNavigationBar.NavigationButton(title: "Cancel") {
                dismiss()
            },
            trailingButton: CustomNavigationBar.NavigationButton(
                title: existingGeofence != nil ? "Update" : "Done",
                isDisabled: !canCreateGeofence || isLoading
            ) {
                createGeofence()
            }
        ) {
            ScrollView {
                VStack(spacing: 20) {
                // Location Alert Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location Alert Name")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    TextField("e.g., School, Home, Park", text: $geofenceName)
                        .padding(12)
                        .background(AppColors.surface)
                        .cornerRadius(8)
                }
                
                // Radius Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Radius")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack {
                        Slider(value: $selectedRadius, in: 50...1000, step: 50)
                            .accentColor(AppColors.primary)
                        
                        Text("\(Int(selectedRadius))m")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
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
                                        selectedRadius == radius ? AppColors.primary : AppColors.buttonSurface
                                    )
                                    .foregroundColor(selectedRadius == radius ? .white : AppColors.textPrimary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Location Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let coordinate = selectedCoordinate {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(AppColors.primary)
                            
                            VStack(alignment: .leading) {
                                Text("Lat: \(coordinate.latitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Lng: \(coordinate.longitude, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingLocationPicker = true
                            }) {
                                Text("Change")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(AppColors.primary)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(AppColors.buttonSurface)
                        .cornerRadius(8)
                    } else {
                        Button(action: {
                            showingLocationPicker = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Select Location")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.primary)
                            .cornerRadius(25)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 8)
                    }
                }
                
                // Preview Map
                if let coordinate = selectedCoordinate {
                    GeofencePreviewMap(
                        coordinate: coordinate,
                        radius: selectedRadius,
                        geofenceName: geofenceName.isEmpty ? "New Location Alert" : geofenceName,
                        isInteractive: false
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(AppColors.errorColor)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                }
                .padding()
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedCoordinate: $selectedCoordinate)
                    .environmentObject(locationService)
            }
            .onAppear {
                // Request location permission
                locationManager.requestLocationPermission()
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                // Location is available - LocationPickerView will handle centering
                if let location = newLocation {
                    print("📍 CreateGeofenceView: User location available: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                }
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
                        radius: selectedRadius,
                        notifyOnEnter: existingGeofence.notifyOnEnter,
                        notifyOnExit: existingGeofence.notifyOnExit
                    )
                } else {
                    // Create new geofence (defaults to notifications enabled)
                    try await geofenceService.createGeofence(
                        familyId: familyId,
                        name: geofenceName.trimmingCharacters(in: .whitespacesAndNewlines),
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        radius: selectedRadius,
                        notifyOnEnter: true,
                        notifyOnExit: true
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
    @EnvironmentObject var locationService: LocationService
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchDelegate = SearchCompleterDelegate()
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var region: MKCoordinateRegion
    
    init(selectedCoordinate: Binding<CLLocationCoordinate2D?>) {
        self._selectedCoordinate = selectedCoordinate
        
        // Initialize region with existing coordinate or default to a reasonable location
        let center = selectedCoordinate.wrappedValue ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // Default to San Francisco
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
            ScrollView {
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
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { result in
                                    SearchResultRow(result: result) {
                                        performSearch(for: result)
                                    }
                                }
                            }
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
                    .frame(height: 300)
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
                            .foregroundColor(AppColors.textSecondary)
                        
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
                            .background(AppColors.systemBlue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
            .onAppear {
                // Use LocationService for user location
                if let userLocation = locationService.currentLocation {
                    region.center = userLocation.coordinate
                    print("📍 LocationPickerView: Centered on user location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
                } else if let localLocation = locationManager.location {
                    region.center = localLocation.coordinate
                    print("📍 LocationPickerView: Centered on local location: \(localLocation.coordinate.latitude), \(localLocation.coordinate.longitude)")
                }
                setupSearchCompleter()
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                // Update region when location becomes available
                if let location = newLocation {
                    region.center = location.coordinate
                    print("📍 LocationPickerView: Updated to user location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                }
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
        // Immediately set flag and close UI to prevent double-tap
        isSelectingLocation = true
        showingSearchResults = false
        searchResults = []
        searchText = completion.title
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Small delay to ensure UI updates before search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let searchRequest = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: searchRequest)
            
            search.start { response, error in
                guard let response = response,
                      let mapItem = response.mapItems.first else {
                    DispatchQueue.main.async {
                        self.isSelectingLocation = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    let coordinate = mapItem.placemark.coordinate
                    self.region.center = coordinate
                    self.selectedCoordinate = coordinate
                    
                    // Reset flag after selection is complete
                    self.isSelectingLocation = false
                }
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
                        .foregroundColor(AppColors.textSecondary)
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
                        .stroke(AppColors.errorColor, lineWidth: 2)
                        .frame(width: CGFloat(radius / 10), height: CGFloat(radius / 10))
                        .opacity(0.6)
                    
                    Text(annotation.name)
                        .font(.caption)
                        .padding(4)
                        .background(AppColors.overlayLight)
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
