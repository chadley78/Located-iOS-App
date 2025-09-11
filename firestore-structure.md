# Firestore Database Structure Documentation

## Overview
This document outlines the Firestore database structure for the Located child safety application. The database is designed with security-first principles to ensure that only authorized users can access sensitive location data.

## Collections Structure

### 1. `/users/{userId}` Collection
**Purpose**: Store user profile information and parent-child relationships

**Document Structure**:
```json
{
  "name": "Alex Johnson",
  "email": "alex@example.com",
  "userType": "child", // or "parent"
  "parents": ["parent_user_id_1", "parent_user_id_2"], // Array of parent user IDs
  "children": ["child_user_id_1", "child_user_id_2"], // Array of child user IDs (for parents)
  "createdAt": "2024-01-15T10:30:00Z",
  "lastActive": "2024-01-15T15:45:00Z",
  "profileImageUrl": "https://storage.googleapis.com/...",
  "isActive": true
}
```

**Security Rules**:
- Users can only read/write their own profile
- Parents can read children's profiles if they are in the parents array

### 2. `/locations/{childId}` Collection
**Purpose**: Store real-time location data for children

**Document Structure**:
```json
{
  "lat": 40.7128,
  "lng": -74.0060,
  "accuracy": 5.0, // Location accuracy in meters
  "timestamp": 1678886400000, // Unix timestamp
  "address": "123 Main St, New York, NY 10001", // Optional reverse geocoded address
  "batteryLevel": 85, // Device battery level
  "isMoving": true, // Whether device is currently moving
  "lastUpdated": "2024-01-15T15:45:00Z"
}
```

**Security Rules**:
- Children can only write to their own location document
- Parents can read their children's location data

### 3. `/geofences/{geofenceId}` Collection
**Purpose**: Store geofence definitions created by parents

**Document Structure**:
```json
{
  "name": "School",
  "description": "Alex's school campus",
  "childId": "child_user_id_1",
  "center": {
    "lat": 40.7589,
    "lng": -73.9851
  },
  "radius": 100, // Radius in meters
  "isActive": true,
  "createdBy": "parent_user_id_1",
  "createdAt": "2024-01-15T10:30:00Z",
  "lastTriggered": "2024-01-15T14:20:00Z",
  "triggerCount": 5 // Number of times this geofence has been triggered
}
```

**Security Rules**:
- Parents can create/manage geofences for their children
- Children cannot directly modify geofences

### 4. `/geofence_events/{eventId}` Collection
**Purpose**: Log geofence enter/exit events

**Document Structure**:
```json
{
  "childId": "child_user_id_1",
  "geofenceId": "geofence_id_1",
  "eventType": "enter", // or "exit"
  "location": {
    "lat": 40.7589,
    "lng": -73.9851
  },
  "timestamp": 1678886400000,
  "geofenceName": "School",
  "notificationSent": true,
  "createdAt": "2024-01-15T14:20:00Z"
}
```

**Security Rules**:
- Children can write geofence events for themselves
- Parents can read geofence events for their children

### 5. `/parent_child_invitations/{invitationId}` Collection
**Purpose**: Manage parent-child relationship invitations

**Document Structure**:
```json
{
  "parentId": "parent_user_id_1",
  "childId": "child_user_id_1",
  "invitationCode": "ABC123", // Unique code for child to accept
  "status": "pending", // "pending", "accepted", "declined", "expired"
  "createdAt": "2024-01-15T10:30:00Z",
  "expiresAt": "2024-01-22T10:30:00Z", // 7 days from creation
  "acceptedAt": null,
  "parentName": "John Johnson",
  "childName": "Alex Johnson"
}
```

**Security Rules**:
- Parents can create invitations
- Children can read invitations sent to them
- Children can update invitations (accept/decline)

## Sample Parent-Child Relationship Data

### Parent User Document
```json
{
  "name": "John Johnson",
  "email": "john@example.com",
  "userType": "parent",
  "parents": [],
  "children": ["child_user_id_1", "child_user_id_2"],
  "createdAt": "2024-01-15T10:30:00Z",
  "lastActive": "2024-01-15T15:45:00Z",
  "isActive": true
}
```

### Child User Document
```json
{
  "name": "Alex Johnson",
  "email": "alex@example.com",
  "userType": "child",
  "parents": ["parent_user_id_1"],
  "children": [],
  "createdAt": "2024-01-15T10:30:00Z",
  "lastActive": "2024-01-15T15:45:00Z",
  "isActive": true
}
```

### Child Location Document
```json
{
  "lat": 40.7128,
  "lng": -74.0060,
  "accuracy": 5.0,
  "timestamp": 1678886400000,
  "address": "123 Main St, New York, NY 10001",
  "batteryLevel": 85,
  "isMoving": true,
  "lastUpdated": "2024-01-15T15:45:00Z"
}
```

## Security Considerations

1. **Authentication Required**: All operations require valid Firebase Authentication
2. **User Isolation**: Users can only access their own data
3. **Parent-Child Relationships**: Strictly controlled through the parents array
4. **Data Validation**: All writes should validate data structure and types
5. **Audit Trail**: Important events are logged with timestamps
6. **Privacy**: Location data is only accessible to authorized parents

## Indexes Required

The following composite indexes should be created in Firestore:

1. **geofence_events**: `childId` + `timestamp` (descending)
2. **geofence_events**: `geofenceId` + `timestamp` (descending)
3. **parent_child_invitations**: `childId` + `status`
4. **parent_child_invitations**: `parentId` + `status`

## Deployment Notes

1. Deploy security rules using: `firebase deploy --only firestore:rules`
2. Create indexes using the Firebase Console or CLI
3. Test security rules using the Firebase Console Rules Playground
4. Monitor usage and performance through Firebase Console Analytics
