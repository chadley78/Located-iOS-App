# FCM Token Registration Fix

## Issue
Parent devices were unable to receive test notifications because FCM token registration was failing with the error:
```
Failed to get FCM token. The operation couldn't be completed. No APNS token specified before fetching FCM token
```

## Root Cause
The app was trying to fetch the FCM (Firebase Cloud Messaging) token **before** receiving the APNs (Apple Push Notification Service) token from Apple. Firebase Messaging requires the APNs token first before it can generate an FCM token.

**Previous Flow (Broken)**:
1. Parent goes to settings → triggers `registerFCMToken()`
2. Requests notification permission ✅
3. Registers for remote notifications ✅
4. **IMMEDIATELY** tries to fetch FCM token ❌ (APNs token not received yet)
5. Firebase fails with "No APNS token specified"

## Solution
Changed the approach to use Firebase Messaging's delegate callback system, which automatically notifies us when the FCM token is ready (after APNs token is received).

**New Flow (Fixed)**:
1. Parent goes to settings → triggers `registerFCMToken()`
2. Requests notification permission ✅
3. Registers for remote notifications ✅
4. Waits 2 seconds for APNs token to arrive
5. Attempts to fetch FCM token (with error handling)
6. If token not ready, the `MessagingDelegate` will automatically save it when available

### Changes Made

#### 1. NotificationService.swift
- **Modified `registerFCMToken()`**:
  - Added 2-second delay to allow APNs token to be received
  - Wrapped FCM token fetch in try-catch with graceful error handling
  - Removed error display to user if token not ready (expected behavior)
  - Added logging to explain what's happening
  - Created separate `saveFCMTokenToFirestore()` method for reusability

#### 2. MessagingDelegate.swift
- **Enhanced `didReceiveRegistrationToken` callback**:
  - Now automatically saves FCM token to Firestore when received
  - Checks for authenticated user before saving
  - Provides detailed logging for debugging
  - This ensures token is saved even if `registerFCMToken()` times out

## How It Works Now

### First-Time Registration
1. User opens parent app for first time
2. Goes to settings or home screen
3. App requests notification permission
4. Registers for remote notifications with Apple
5. Apple sends APNs token to app
6. Firebase Messaging generates FCM token
7. `MessagingDelegate.didReceiveRegistrationToken()` fires
8. Token is automatically saved to Firestore
9. Parent is now registered for notifications ✅

### Subsequent App Launches
1. User opens parent app
2. FCM token already exists in Firebase Messaging
3. `registerFCMToken()` successfully fetches token (after 2-second delay)
4. Token is saved to Firestore (if not already there)
5. Parent remains registered for notifications ✅

## Testing Instructions

### Test 1: Fresh Parent Registration
1. Delete the app from device (to clear all tokens)
2. Reinstall and build in Xcode
3. Login as parent
4. Go to settings or home screen
5. **Expected console logs**:
   ```
   ✅ Notification permission granted
   ✅ Registered for remote notifications
   ⏳ Waiting for FCM token to be generated...
   💡 The FCM token will be automatically saved when Firebase Messaging receives the APNs token
   📱 APNs token received: <token_data>
   🔄 FCM Registration Token: <fcm_token>
   ✅ FCM token stored locally: <fcm_token>
   ✅ FCM token automatically saved to Firestore: <fcm_token>
   ```

6. **Check Firestore**:
   - Open Firebase Console → Firestore
   - Find parent user document in `users` collection
   - Verify `fcmTokens` array exists and contains a token
   - Token should be a long string **without colons** (colons indicate old invalid format)

### Test 2: Test Notification from Child
1. Build child app
2. Login as child
3. Enable location sharing
4. Tap "Send Test Notification" button in child settings
5. **Expected child console logs**:
   ```
   ✅ Test geofence notification triggered
   ```

6. **Expected parent result**:
   - Parent device should receive a push notification
   - Notification should show child name and location details
   - If app is open, notification appears as banner
   - If app is closed, notification appears in notification center

### Test 3: Verify Token Format
1. Open Firebase Console → Firestore
2. Check parent user's `fcmTokens` array
3. **Valid token format**: Long string like `cN3Xj8fxQ0...` (no colons)
4. **Invalid token format**: String with colons like `deviceId:randomString:timestamp`
5. If invalid tokens found, they need to be cleaned up

## Console Logs to Monitor

### Success Indicators ✅
- `✅ FCM token stored locally: <token>`
- `✅ FCM token automatically saved to Firestore: <token>`
- `✅ FCM token registered: <token>`
- `📱 Parent registered for geofence notifications`

### Expected Info Logs ℹ️
- `ℹ️ FCM token not ready yet: <error>`
- `ℹ️ Token will be automatically registered when available via MessagingDelegate`

### Warning Signs ⚠️
- `⚠️ Cannot save FCM token - user not authenticated`
- `⚠️ Notification permission denied`

### Errors to Investigate ❌
- `❌ Failed to save FCM token to Firestore: <error>`
- `❌ Failed to register FCM token: <error>`

## Troubleshooting

### Issue: "No APNS token specified" still appears
**Solution**: The 2-second delay might not be enough on slower devices. The token will still be saved via the delegate callback, so this can be ignored.

### Issue: Token saved but notifications not received
**Possible causes**:
1. **Invalid token format** - Check Firestore for tokens with colons
2. **Cloud Function not deployed** - Verify `sendDebugNotification` is deployed
3. **Firestore security rules** - Check that parents can read child events
4. **Network issues** - Check device has internet connection

### Issue: Token not appearing in Firestore
**Debug steps**:
1. Check console for authentication errors
2. Verify user is logged in when token is received
3. Check Firestore security rules allow token writes
4. Look for "Cannot save FCM token - user not authenticated" log

## Files Modified
- `/LocatedApp/LocatedApp/NotificationService.swift` - Updated token registration logic
- `/LocatedApp/LocatedApp/MessagingDelegate.swift` - Added automatic Firestore saving

## Next Steps
1. Build the app in Xcode (you mentioned you prefer GUI over terminal) [[memory:8783530]]
2. Test with a parent device to verify token registration
3. Test notification sending from child device
4. Monitor console logs to verify proper flow
5. Check Firestore to confirm valid tokens are saved

## Related Documentation
- `NOTIFICATION_IMPLEMENTATION_GUIDE.md` - Full notification system overview
- `MAP_LOGIC_README.md` - Parent map and location tracking
- `GEOFENCE_NOTIFICATIONS.md` - Geofence notification setup

