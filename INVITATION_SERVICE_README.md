# Family Invitation Service

## Overview
The Family Invitation Service handles the complete flow of inviting children to join a family and managing the invitation acceptance process. This includes creating invitations, accepting them, and updating both the family and user documents in Firestore.

## Architecture

### Components
- **FamilyInvitationService** - Handles invitation creation and acceptance
- **AcceptFamilyInvitationView** - UI for accepting invitations
- **Cloud Function: acceptInvitation** - Backend logic for processing invitations
- **Cloud Function: createFamily** - Creates new families with parent members

### Data Flow

#### 1. Creating an Invitation
```
Parent App → FamilyInvitationService.createInvitation() → Firestore (invitations collection)
```

#### 2. Accepting an Invitation
```
Child App → AcceptFamilyInvitationView → Cloud Function (acceptInvitation) → Updates:
  - Family document (adds child to members)
  - User document (sets familyId and correct name)
  - Invitation document (marks as used)
```

## Key Features

### Invitation Creation
- Generates unique 6-character invite codes
- Sets expiration time (7 days)
- Stores child name for later use
- Only parents can create invitations

### Invitation Acceptance
- Validates invite code and expiration
- Handles both new and existing child accounts
- Updates child's name in user document
- Adds child to family members
- Marks invitation as used

### Welcome Flow
- Shows "Setting up account..." message during processing
- Transitions to welcome message after 2.5 seconds
- Provides smooth user experience during Cloud Function execution

## Code Structure

### FamilyInvitationService.swift
```swift
class FamilyInvitationService: ObservableObject {
    // Creates invitations with unique codes
    func createInvitation(childName: String, familyId: String) async throws -> String
    
    // Accepts invitations via Cloud Function
    func acceptInvitation(inviteCode: String, childName: String) async throws
}
```

### AcceptFamilyInvitationView.swift
```swift
struct AcceptFamilyInvitationView: View {
    // Handles invitation code input
    // Shows welcome screens
    // Manages loading states
}
```

### Cloud Functions (functions/index.js)
```javascript
// acceptInvitation - Processes invitation acceptance
exports.acceptInvitation = onCall(async (data, context) => {
  // Validates invitation
  // Updates family and user documents
  // Handles both new and existing children
});

// createFamily - Creates new families
exports.createFamily = onCall(async (data, context) => {
  // Creates family document
  // Adds parent as first member
  // Updates user's familyId
});
```

## Database Schema

### Invitations Collection
```javascript
{
  id: "M9GP4K", // 6-character invite code
  familyId: "uuid",
  createdBy: "parentUserId",
  childName: "Emma",
  createdAt: timestamp,
  expiresAt: timestamp,
  usedBy: "childUserId", // null until used
  usedAt: timestamp // null until used
}
```

### Families Collection
```javascript
{
  id: "uuid",
  name: "The Butterfield Family",
  createdBy: "parentUserId",
  createdAt: timestamp,
  members: {
    "parentUserId": {
      role: "parent",
      name: "Darragh Flood",
      joinedAt: timestamp
    },
    "childUserId": {
      role: "child", 
      name: "Emma",
      joinedAt: timestamp
    }
  }
}
```

### Users Collection
```javascript
{
  id: "userId",
  name: "Emma", // Updated by Cloud Function
  email: "child_temp@temp.located.app",
  userType: "child",
  familyId: "familyUuid", // Set by Cloud Function
  // ... other fields
}
```

## Error Handling

### Common Issues
1. **Expired Invitations** - Check `expiresAt` timestamp
2. **Already Used Invitations** - Check `usedBy` field
3. **Invalid Invite Codes** - Validate format and existence
4. **Permission Errors** - Ensure user is authenticated

### Error Messages
- "Invitation not found" - Invalid invite code
- "Invitation has expired" - Past expiration date
- "Invitation already used" - Previously accepted
- "You are not authorized" - Permission denied

## Testing

### Test Scenarios
1. **Valid Invitation** - Should accept successfully
2. **Expired Invitation** - Should show expiration error
3. **Used Invitation** - Should show already used error
4. **Invalid Code** - Should show not found error
5. **New vs Existing Child** - Both paths should work

### Debug Information
The child app includes debug UI showing:
- Child Name
- Family Name  
- Family ID
- User ID

## Security

### Firestore Rules
- Invitations collection: No direct client access (Cloud Functions only)
- Families collection: Members can read, parents can write
- Users collection: Users can read/write their own documents

### Cloud Function Security
- Validates authentication
- Checks invitation validity
- Ensures proper permissions
- Updates multiple documents atomically

## Future Enhancements

### Potential Improvements
1. **Bulk Invitations** - Invite multiple children at once
2. **Invitation Management** - View/cancel pending invitations
3. **Email Notifications** - Send invitation links via email
4. **QR Codes** - Generate QR codes for invitations
5. **Invitation History** - Track all invitation activity

### Performance Optimizations
1. **Caching** - Cache family data locally
2. **Batch Operations** - Batch Firestore writes
3. **Real-time Updates** - Use Firestore listeners for live updates
4. **Offline Support** - Handle offline invitation acceptance

## Troubleshooting

### Common Problems
1. **Child name shows as "Child"** - Cloud Function didn't update user document
2. **Family not found** - Check familyId in user document
3. **Permission denied** - Verify Firestore security rules
4. **Cloud Function timeout** - Check function logs for errors

### Debug Steps
1. Check Cloud Function logs: `firebase functions:log --only acceptInvitation`
2. Verify Firestore documents exist and have correct data
3. Check user authentication status
4. Validate invitation code format and expiration
