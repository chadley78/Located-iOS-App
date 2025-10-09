# Periodic Location Updates Implementation

## Overview
Implemented adaptive periodic location updates to ensure parents stay connected to child devices even when stationary. Previously, children only updated location when moving 100m+, which could result in no updates for hours if stationary.

## Implementation Date
October 9, 2025

## Changes Made

### 1. Configuration Constants Added
Located in `LocationService.swift` lines 56-61:

```swift
// Periodic update intervals for different scenarios
private let periodicUpdateIntervalMoving: TimeInterval = 120 // 2 minutes when moving
private let periodicUpdateIntervalStationary: TimeInterval = 300 // 5 minutes when stationary
private let periodicUpdateIntervalLowBattery: TimeInterval = 600 // 10 minutes when battery < 20%
private let periodicUpdateIntervalVeryLowBattery: TimeInterval = 900 // 15 minutes when battery < 10%
private let lowBatteryThreshold: Int = 20 // Battery percentage threshold
private let veryLowBatteryThreshold: Int = 10 // Critical battery threshold
```

**Easily adjustable** - Change these constants to tune update frequency.

### 2. New Properties
- `periodicLocationTimer: Timer?` - Manages periodic updates
- `lastFirestoreUpdateTime: Date?` - Prevents duplicate rapid updates

### 3. New Methods

#### `getCurrentMovementState() -> TimeInterval`
- Returns appropriate update interval based on:
  1. Battery level (highest priority)
  2. Movement state (based on speed > 1.0 m/s)
- Includes debug logging for troubleshooting

#### `requestPeriodicLocationUpdate()`
- Triggered by timer
- Checks if enough time has passed since last update
- Uses current location or requests fresh one
- Saves to Firestore with updated timestamp

#### `setupPeriodicLocationTimer()`
- Creates adaptive repeating timer
- Automatically adjusts interval based on current state
- Restarts timer after each fire to adapt to state changes
- Runs in `.common` RunLoop mode for background operation

### 4. Integration Points

**Start Location Updates** (`startLocationUpdates()`):
- Calls `setupPeriodicLocationTimer()` after starting standard location services
- Timer begins immediately when child enables location sharing

**Stop Location Updates** (`stopLocationUpdates()`):
- Invalidates and cleans up timer
- Prevents memory leaks

**Firestore Updates** (`saveLocationToFirestore()`):
- Sets `lastFirestoreUpdateTime` on every save
- Ensures timestamp tracking is accurate

## Update Intervals

| Child State | Update Frequency | Rationale |
|------------|------------------|-----------|
| **Moving** | 2 minutes | Parents want frequent updates during transit |
| **Stationary** | 5 minutes | Stay connected without excessive battery drain |
| **Low Battery (<20%)** | 10 minutes | Preserve battery when running low |
| **Very Low (<10%)** | 15 minutes | Emergency battery preservation |

## How It Works

### Automatic Adaptation
1. Timer fires based on current state interval
2. `requestPeriodicLocationUpdate()` checks if enough time has passed
3. Updates Firestore if criteria met
4. Timer restarts with potentially new interval (adapts to state changes)

### Battery Efficiency
- Prioritizes battery level checks first
- Uses existing location when available (no GPS polling)
- Only requests fresh location if none cached
- Works alongside existing distance-based updates

### Duplicate Prevention
The `lastFirestoreUpdateTime` tracking prevents duplicate updates from:
- Periodic timer firing too soon
- Existing distance-based triggers
- Multiple simultaneous update requests

## Debugging

### Console Logs to Look For

**Timer Setup:**
```
⏰ Setting up periodic location timer with interval: 300s
```

**Movement State Detection:**
```
🛑 Child stationary - using 300s interval
🚶 Child moving - using 120s interval
🔋 Low battery (15%) - using 600s interval
```

**Periodic Updates:**
```
⏰ Periodic location update triggered
⏰ Using current location for periodic update
📍 Location saved to Firestore: 53.29526, -6.301476
```

**Skipped Updates:**
```
⏰ Skipping update - only 120s since last update (need 300s)
```

## Testing Checklist

### Tasks 12-15: Testing Scenarios

- [ ] **Task 12**: Child stationary - Verify Firestore updates every 5 minutes
  - Build child app in Xcode
  - Enable location sharing
  - Keep device stationary
  - Monitor console logs for "⏰ Periodic location update triggered"
  - Check Firestore console for updates every ~5 minutes

- [ ] **Task 13**: Child moving - Verify updates every 2 minutes  
  - Build child app in Xcode
  - Enable location sharing
  - Move device/walk around
  - Look for "🚶 Child moving" logs
  - Verify faster update frequency (~2 minutes)

- [ ] **Task 14**: Low battery - Verify reduced frequency
  - Simulate low battery (Settings > Battery) or wait for actual low battery
  - Look for "🔋 Low battery" logs
  - Verify 10-minute or 15-minute intervals

- [ ] **Task 15**: Parent map - Verify timestamp updates
  - Build parent app in Xcode
  - View stationary child on map
  - Check "last seen" timestamp updates every ~5 minutes
  - Verify UI feels "connected"

## Rollback Instructions

If issues arise, the feature can be disabled without code changes:

1. Open `LocationService.swift`
2. Comment out line 159: `setupPeriodicLocationTimer()`
3. App reverts to original distance-based updates only

## Future Enhancements

Potential improvements:
1. Server-side configuration of intervals
2. User preferences for update frequency
3. Location history analytics to optimize intervals
4. Push notification wake-ups for more reliable background updates
5. Adaptive intervals based on time of day (e.g., less frequent at night)

## Performance Considerations

### Battery Impact
- Minimal when stationary (uses cached location)
- Moderate when moving (GPS already active)
- Adaptive intervals reduce battery drain on low battery

### Network Impact
- Small Firestore writes every 2-5 minutes
- ~50-100 bytes per update
- Well within free tier limits for most users

### Background Reliability
- Timers in background can be suspended by iOS
- "Always" location permission helps keep app alive
- Consider BGTaskScheduler for more reliable background execution in future

## Known Limitations

1. **iOS Background Restrictions**: iOS may suspend timers after extended background time
2. **Battery Monitoring**: Battery level reported as -100 on simulator
3. **Movement Detection**: Relies on `location.speed`, may not detect very slow movement
4. **Timer Precision**: Timer may not fire exactly on schedule in background

## Related Files

- `LocationService.swift` - Main implementation
- `MAP_LOGIC_README.md` - Parent map logic documentation
- `INVITATION_SERVICE_README.md` - Child invitation flow
- `rules.md` - Project development guidelines

