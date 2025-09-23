# Parent Map Logic & Child Location Tracking

## Overview
The Parent Map Logic handles displaying child locations on a map, managing real-time location updates, and providing interactive features like centering on children and manual refresh. This system ensures parents can track their children's locations in real-time.

## Architecture

### Components
- **ParentMapViewModel** - Manages map state and child locations
- **MapViewRepresentable** - SwiftUI wrapper for MapKit
- **FamilyService** - Provides family member data
- **LocationService** - Handles location updates from children

### Data Flow

#### 1. Initial Load
```
Parent App Start → FamilyService loads family → MapViewModel waits for family data → 
Starts location listeners → Receives child locations → Updates map
```

#### 2. Real-time Updates
```
Child App → LocationService → Firestore (locations collection) → 
Parent App listeners → MapViewModel → Map updates
```

#### 3. Manual Refresh
```
User taps refresh → MapViewModel.refreshChildrenLocations() → 
Restarts listeners → Updates map
```

## Key Features

### Automatic Child Detection
- Waits for family data to load before starting location listeners
- Automatically detects new children when they join the family
- Handles timing issues with retry logic

### Real-time Location Updates
- Listens to Firestore `locations` collection for each child
- Updates map annotations in real-time
- Handles location document creation/deletion

### Map Centering
- Centers on children when locations are received
- Centers on individual children when clicked
- Provides manual refresh functionality

### Visual Indicators
- Color-coded pins for each child
- Recent location indicators (green checkmarks)
- Battery level and last seen timestamps

## Code Structure

### ParentMapViewModel.swift
```swift
class ParentMapViewModel: ObservableObject {
    @Published var childrenLocations: [ChildLocationData] = []
    @Published var region: MKCoordinateRegion
    
    // Starts listening for child locations
    func startListeningForChildrenLocations(parentId: String, familyService: FamilyService)
    
    // Centers map on all children
    func centerOnChildren()
    
    // Centers map on specific child
    func centerOnChild(childId: String)
    
    // Manual refresh
    func refreshChildrenLocations()
}
```

### MapViewRepresentable.swift
```swift
struct MapViewRepresentable: UIViewRepresentable {
    // Renders MapKit view with child annotations
    // Handles annotation selection and updates
    // Manages map region changes
}
```

## Database Schema

### Locations Collection
```javascript
{
  "childUserId": {
    lat: 53.29526,
    lng: -6.301476,
    accuracy: 5,
    timestamp: timestamp,
    lastUpdated: timestamp,
    address: "1 Butterfield Grove Dublin 14 Co. Dublin D14 NY16",
    familyId: "familyUuid",
    batteryLevel: -100,
    isMoving: 0
  }
}
```

### ChildLocationData Model
```swift
struct ChildLocationData {
    let childId: String
    let location: LocationData
    let lastSeen: Date
    let childName: String
}
```

## Timing & Synchronization

### Initial Load Timing
The system handles the timing issue where family data might not be loaded when MapViewModel starts:

```swift
// Wait for family data to be loaded
var attempts = 0
while attempts < 10 { // Try for up to 5 seconds
    let children = familyService.getChildren()
    if !children.isEmpty {
        // Start location listeners
        break
    }
    try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
    attempts += 1
}
```

### Family Change Detection
- FamilyService automatically updates when family members change
- MapViewModel responds to family changes by updating location listeners
- New children are automatically detected and monitored

## Map Centering Logic

### Automatic Centering
```swift
private func checkAndCenterMapIfNeeded() {
    // Center if we have at least one child location
    if childrenLocations.count >= 1 {
        centerOnChildren()
    }
}
```

### Manual Centering
- **Center on All Children**: Shows all children in view
- **Center on Specific Child**: Focuses on individual child
- **Refresh Button**: Restarts location listeners

## Visual Features

### Child Pins
- **Unique Colors**: Each child gets a distinct color
- **Recent Indicators**: Green checkmarks for recent locations
- **Battery Status**: Shows battery level
- **Last Seen**: Timestamp of last location update

### Color Assignment
```swift
private let childColors: [UIColor] = [
    .systemBlue, .systemGreen, .systemOrange, .systemRed,
    .systemPurple, .systemYellow, .systemTeal, .systemPink
]

func getColorForChild(childId: String) -> UIColor {
    let hash = childId.hashValue
    let index = abs(hash) % childColors.count
    return childColors[index]
}
```

## Error Handling

### Common Issues
1. **No Family Data** - Waits for family to load
2. **Missing Location Documents** - Handles gracefully
3. **Permission Errors** - Logs and continues
4. **Network Issues** - Retries automatically

### Debug Information
Extensive logging for troubleshooting:
- `🔍 MapViewModel - Found X children to monitor`
- `🔍 MapViewModel - Setting up Firestore listener for locations/childId`
- `🔍 MapViewModel - Received location data for child`
- `🔍 MapViewModel - Centering map with X children`

## Performance Optimizations

### Efficient Updates
- Only updates changed locations
- Batches map updates
- Uses weak references to prevent memory leaks
- Cleans up listeners when not needed

### Memory Management
```swift
// Clean up listeners
listeners.forEach { $0.remove() }
listeners.removeAll()
childrenLocations.removeAll()
```

## Security

### Firestore Rules
```javascript
// Locations collection - children can write, family members can read
match /locations/{childId} {
  allow write: if request.auth != null && request.auth.uid == childId;
  allow read: if request.auth != null; // Temporarily permissive
}
```

### Data Validation
- Validates child IDs before making Firestore calls
- Checks for empty strings and nil values
- Handles malformed location data gracefully

## Testing

### Test Scenarios
1. **Initial Load** - Map centers on children when app starts
2. **New Child Joins** - Child appears on map automatically
3. **Location Updates** - Real-time location changes
4. **Manual Refresh** - Refresh button works correctly
5. **Child Click** - Clicking child centers map on them

### Debug Tools
- Debug UI showing child information
- Extensive console logging
- Map annotation counts
- Location update timestamps

## Troubleshooting

### Common Problems
1. **Children not appearing** - Check family data loading
2. **Map not centering** - Verify centering logic conditions
3. **Location not updating** - Check Firestore listeners
4. **Performance issues** - Monitor listener cleanup

### Debug Steps
1. Check console logs for MapViewModel messages
2. Verify family data is loaded in FamilyService
3. Check Firestore security rules
4. Validate location documents exist
5. Test manual refresh functionality

## Future Enhancements

### Potential Improvements
1. **Geofencing** - Set up location-based alerts
2. **Location History** - Track location over time
3. **Route Tracking** - Show movement paths
4. **Offline Support** - Cache locations locally
5. **Push Notifications** - Alert on location changes

### Performance Optimizations
1. **Location Batching** - Batch multiple location updates
2. **Smart Centering** - Only center when necessary
3. **Background Updates** - Continue tracking when app is backgrounded
4. **Data Compression** - Reduce location data size

## Integration Points

### With Other Services
- **FamilyService** - Provides family member data
- **LocationService** - Handles child location updates
- **AuthenticationService** - Manages user authentication
- **GeofenceService** - Location-based alerts

### API Dependencies
- **Firestore** - Real-time database
- **MapKit** - Map rendering
- **Core Location** - Location services
- **Firebase Auth** - User authentication
