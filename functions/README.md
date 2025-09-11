# Firebase Cloud Functions - BE-03 Implementation

## Overview
This document describes the Firebase Cloud Functions implementation for push notifications when geofence events occur.

## Functions Implemented

### 1. `onGeofenceEvent` (Main Function)
**Trigger**: Firestore document created in `geofence_events/{eventId}`
**Purpose**: Sends push notifications to parents when their child enters/exits a geofence

**Process Flow**:
1. Triggered when a new document is created in `geofence_events` collection
2. Extracts event details (childId, eventType, geofenceName, etc.)
3. Looks up the child's profile to find authorized parents
4. Retrieves FCM tokens for all parents
5. Sends push notification with event details
6. Handles failed tokens by cleaning them up

**Event Data Structure**:
```javascript
{
  childId: "string",           // Required: ID of the child
  childName: "string",          // Optional: Name of the child
  geofenceId: "string",         // Optional: ID of the geofence
  geofenceName: "string",       // Optional: Name of the geofence
  eventType: "enter" | "exit",  // Required: Type of event
  timestamp: number,            // Optional: Event timestamp
  location: {                   // Optional: Location data
    lat: number,
    lng: number,
    address: "string"
  }
}
```

### 2. `testGeofenceNotification` (Test Function)
**Trigger**: HTTP request
**Purpose**: Test endpoint to manually trigger geofence notifications

**Usage**:
```bash
curl -X POST https://your-project.cloudfunctions.net/testGeofenceNotification \
  -H "Content-Type: application/json" \
  -d '{
    "childId": "actual-child-id",
    "childName": "Test Child",
    "geofenceName": "School",
    "eventType": "enter",
    "lat": 37.7749,
    "lng": -122.4194,
    "address": "Test Location"
  }'
```

### 3. `registerFCMToken` (Utility Function)
**Trigger**: HTTP request
**Purpose**: Register FCM tokens for users to receive notifications

**Usage**:
```bash
curl -X POST https://your-project.cloudfunctions.net/registerFCMToken \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-id",
    "fcmToken": "fcm-token-string"
  }'
```

## Deployment Instructions

### Prerequisites
1. Firebase CLI installed: `npm install -g firebase-tools`
2. Firebase project configured
3. Node.js 22+ installed

### Deploy Functions
```bash
# Navigate to functions directory
cd functions

# Install dependencies
npm install

# Deploy functions
firebase deploy --only functions
```

### Verify Deployment
```bash
# Check function logs
firebase functions:log

# List deployed functions
firebase functions:list
```

## Testing the Functions

### 1. Test Geofence Event Processing
1. Create a test geofence event in Firestore:
```javascript
// In Firebase Console or via code
db.collection('geofence_events').add({
  childId: 'test-child-id',
  childName: 'Test Child',
  geofenceId: 'test-geofence-id',
  geofenceName: 'School',
  eventType: 'enter',
  timestamp: Date.now(),
  location: {
    lat: 37.7749,
    lng: -122.4194,
    address: 'Test School'
  }
});
```

2. Check Firebase Functions logs for processing:
```bash
firebase functions:log --only onGeofenceEvent
```

### 2. Test HTTP Endpoints
Use the test function to verify the notification system:
```bash
# Test notification
curl -X POST https://your-project.cloudfunctions.net/testGeofenceNotification \
  -H "Content-Type: application/json" \
  -d '{"childId": "your-child-id", "eventType": "enter"}'
```

## Database Schema Updates

### Users Collection
Add `fcmTokens` array to user documents:
```javascript
{
  // ... existing user data
  fcmTokens: ["token1", "token2", "token3"]
}
```

### Geofence Events Collection
New collection for storing geofence events:
```javascript
// Collection: geofence_events
// Document ID: auto-generated
{
  childId: "string",
  childName: "string",
  geofenceId: "string", 
  geofenceName: "string",
  eventType: "enter" | "exit",
  timestamp: number,
  location: {
    lat: number,
    lng: number,
    address: "string"
  }
}
```

## Security Considerations

1. **FCM Token Management**: Failed tokens are automatically cleaned up
2. **Parent Authorization**: Only authorized parents receive notifications
3. **Input Validation**: Required fields are validated before processing
4. **Error Handling**: Comprehensive error logging and handling

## Monitoring and Logging

### Key Metrics to Monitor
- Function execution count
- Function execution duration
- Error rates
- FCM delivery success/failure rates

### Logging
All functions include structured logging for:
- Event processing details
- Notification delivery status
- Error conditions
- Token cleanup operations

## Next Steps

1. **Deploy the functions** to Firebase
2. **Test with real data** using the test endpoints
3. **Implement IOS-04** to create geofence events
4. **Implement IOS-05** to handle notifications in the iOS app
5. **Set up monitoring** and alerting for production use
