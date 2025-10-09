# Geofence Notifications Setup

## Overview
Push notifications for geofence events (when children enter/exit location alerts) are now fully configured and ready to use on **both iOS and Android** devices.

## Implementation Date
October 9, 2025

## How It Works

### Flow
```
1. Child enters/exits geofence
   ↓
2. LocationService logs geofence event to Firestore (geofence_events collection)
   ↓
3. Cloud Function `onGeofenceEvent` triggers automatically
   ↓
4. Function finds all parents in family
   ↓
5. Gets parent FCM tokens from user documents
   ↓
6. Sends push notification to all parent devices
   ↓
7. Parent receives notification (even if app is closed/backgrounded)
```

### Components

#### 1. Cloud Function (`onGeofenceEvent`)
**Location**: `functions/index.js` lines 23-204
**Trigger**: Firestore document created in `geofence_events/{eventId}`
**Status**: ✅ **Already deployed** (verified via `firebase functions:list`)

**What it does:**
- Extracts geofence event details (child, geofence name, enter/exit)
- Finds all parents in the child's family
- Retrieves parent FCM tokens from Firestore
- Sends push notification via Firebase Admin SDK
- Cleans up invalid/expired tokens automatically

#### 2. Parent FCM Registration
**Location**: `ContentView.swift` ParentHomeView `.onAppear` (lines 1436-1440)
**Status**: ✅ **Just added**

**What happens:**
- When parent opens app, automatically requests notification permission
- Registers device with Firebase Cloud Messaging
- Stores FCM token in parent's user document (`fcmTokens` array)
- Happens silently in background on app launch

#### 3. Child Geofence Detection
**Location**: `LocationService.swift` `checkGeofenceContainment()` (lines 481-522)
**Status**: ✅ **Already implemented**

**What triggers events:**
- Every location update (every 2-5 minutes)
- Synthetic events when containment state changes
- Works even if phone restarted, app restarted, or iOS boundary not crossed

## Notification Format

### Title
```
[Child Name] entered/left [Geofence Name]
```
Examples:
- "Emma entered School"
- "Jack left Home"

### Body
```
Location: [Address or "Unknown location"]
```
Example:
- "Location: 123 Main St Dublin D14 NY16"

### Data Payload (for app deep linking)
```json
{
  "type": "geofence_event",
  "childId": "abc123",
  "childName": "Emma",
  "geofenceId": "def456",
  "geofenceName": "School",
  "eventType": "enter",
  "timestamp": "1728492000000",
  "location": "{\"lat\":53.29,\"lng\":-6.30,...}"
}
```

## Cross-Platform Compatibility

### ✅ iOS (Current)
- Uses Firebase Cloud Messaging (FCM)
- APNs (Apple Push Notification service) under the hood
- NotificationService handles permissions and display
- Works in foreground, background, and when app is closed

### ✅ Android (Future-Ready)
- **Same FCM infrastructure works on Android**
- No backend changes needed
- Android app just needs:
  - Firebase SDK integration
  - FCM token registration (same as iOS)
  - Notification permission handling (Android 13+)
- Cloud Function already sends to any FCM token (iOS or Android)

## Testing

### Test Flow
1. **Setup**:
   - Build parent app in Xcode
   - Open app (triggers FCM registration)
   - Check console for "📱 Parent registered for geofence notifications"
   - Check console for "✅ FCM token registered: [token]"

2. **Trigger Event**:
   - Child device enters or exits a geofence
   - Or use simulated location to cross geofence boundary
   - Or turn child phone off outside, on inside geofence

3. **Verify**:
   - Parent device should receive push notification
   - Check Cloud Function logs: `firebase functions:log --only onGeofenceEvent`
   - Look for: "Notification sent for geofence event [id]"

### Debug Commands

**Check deployed functions:**
```bash
firebase functions:list
```

**View Cloud Function logs:**
```bash
firebase functions:log --only onGeofenceEvent
```

**Check specific event:**
```bash
firebase functions:log --only onGeofenceEvent --limit 50
```

## Notification States

### When Notification Shows

| App State | iOS Behavior | Android Behavior |
|-----------|--------------|------------------|
| **Foreground** | Banner at top (configured) | Heads-up notification |
| **Background** | Notification in tray | Notification in tray |
| **Closed** | Notification in tray | Notification in tray |

### When Tapped
- App opens (if closed)
- App comes to foreground (if backgrounded)
- Data payload available for deep linking (future enhancement)

## Token Management

### Registration
- **Parents**: Register on ParentHomeView appearance
- **Children**: Already register on app startup (for future features)

### Storage
- Stored in Firestore: `users/{userId}/fcmTokens` (array)
- Multiple tokens per user supported (multiple devices)

### Cleanup
- Invalid tokens automatically removed by Cloud Function
- Failed send attempts trigger `cleanupFailedTokens()`
- Prevents unnecessary notification attempts

## Security & Privacy

### Who Receives Notifications
- **Only parents in the same family** as the child
- Determined by `families/{familyId}/members` document
- Family membership required to receive notifications

### Data Transmitted
- Child name, geofence name, event type (enter/exit)
- Location address (not exact coordinates in notification)
- Timestamp of event
- All data already visible to parents in app

### Token Security
- FCM tokens are device-specific
- Tokens are not secret (used only for routing)
- Firebase handles authentication via Admin SDK
- No sensitive data in notification payload

## Configuration Files

### iOS Info.plist
**Already configured** - No changes needed
- Background modes: location
- Notification permissions strings

### Firebase Project
**Project**: located-d9dce
**Region**: us-central1
**Functions**: onGeofenceEvent (v2, nodejs22)

### Cloud Function Settings
```javascript
setGlobalOptions({maxInstances: 10}); // Cost control
```

## Costs

### Firebase Cloud Messaging
- **Free**: Up to 10,000,000 notifications/month
- Our usage: ~100-1000/month (very low)

### Cloud Functions
- **Free tier**: 2,000,000 invocations/month
- Our usage: One invocation per geofence event
- Cost: Effectively $0

## Troubleshooting

### Notification Not Received

1. **Check parent FCM token registered:**
   ```
   Console: "📱 Parent registered for geofence notifications"
   Console: "✅ FCM token registered: [long token]"
   ```

2. **Check geofence event logged:**
   ```
   Firestore → geofence_events collection → recent document
   ```

3. **Check Cloud Function triggered:**
   ```bash
   firebase functions:log --only onGeofenceEvent
   ```
   Look for: "Processing geofence event: [id]"

4. **Check notification sent:**
   ```
   Cloud Function logs: "Notification sent for geofence event [id]"
   Check successCount > 0
   ```

5. **Check iOS notification permissions:**
   ```
   Settings → Located App → Notifications → Allow Notifications (ON)
   ```

### Common Issues

**Issue**: "No FCM tokens found for parents"
**Solution**: Ensure parent app has been opened and FCM registration completed

**Issue**: "Failed to send to token"
**Solution**: Token may be invalid/expired - will be auto-cleaned up

**Issue**: Notification shows but no sound
**Solution**: Check device Do Not Disturb settings and app notification settings

## Future Enhancements

### Potential Improvements
1. **Deep Linking**: Tap notification → open child on map
2. **Custom Sounds**: Different sounds for enter vs exit
3. **Notification Grouping**: Group multiple events from same child
4. **Quiet Hours**: Disable notifications during certain times
5. **Notification History**: In-app history of past notifications
6. **Rich Notifications**: Show child photo, map preview
7. **Action Buttons**: "View on Map", "Dismiss" buttons

### Android App
When building Android version:
1. Add Firebase SDK to Android project
2. Copy `google-services.json` to app directory
3. Request notification permissions (Android 13+)
4. Register FCM token (same `registerFCMToken` flow)
5. **That's it!** Cloud Function already compatible

## Related Files

- `functions/index.js` - Cloud Function implementation
- `LocatedApp/LocatedApp/NotificationService.swift` - iOS notification handling
- `LocatedApp/LocatedApp/MessagingDelegate.swift` - FCM token management
- `LocatedApp/LocatedApp/ContentView.swift` - Parent FCM registration
- `LocatedApp/LocatedApp/LocationService.swift` - Geofence event generation

