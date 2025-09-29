# Family Invitation Service

## Overview
The Family Invitation Service handles the complete flow of inviting children to join a family and managing the invitation acceptance process. This includes creating invitations, accepting them, and updating both the family and user documents in Firestore. The system now supports **pending invitations** where children appear in family lists immediately with "Invite not accepted" status, allowing parents to manage them before acceptance.

## Architecture

### Components
- **FamilyInvitationService** - Handles invitation creation and acceptance
- **AcceptFamilyInvitationView** - UI for accepting invitations
- **Cloud Function: acceptInvitation** - Backend logic for processing invitations
- **Cloud Function: createFamily** - Creates new families with parent members
- **Cloud Function: createInvitation** - Creates invitations and pending children
- **FamilyService** - Manages family members including pending children
- **ChildProfileView** - UI for managing both accepted and pending children

### Data Flow

#### 1. Creating an Invitation (with Pending Child)
```
Parent App → FamilyInvitationService.createInvitation() → Cloud Function (createInvitation) → Creates:
  - Invitation document (invitations collection)
  - Pending child as FamilyMember with status: "pending" (families.members)
```

#### 2. Accepting an Invitation
```
Child App → AcceptFamilyInvitationView → Cloud Function (acceptInvitation) → Updates:
  - For pending children: Replaces pending child UUID with authenticated user ID
  - For accepted children: Deletes old child and creates new with authenticated user ID
  - Updates user document (sets familyId and correct name)
  - Marks invitation as used
```

#### 3. Reissuing an Invitation
```
Parent App → ChildProfileView → FamilyInvitationService.createInvitation() → Cloud Function (createInvitation) → Updates:
  - Invalidates old invitation documents
  - Creates new invitation document
  - Keeps existing pending child (no duplicate creation)
```

## Key Features

### Invitation Creation
- Generates unique 6-character invite codes
- Sets expiration time (24 hours)
- Stores child name for later use
- Only parents can create invitations
- **Creates pending child immediately** - Child appears in family lists with "Invite not accepted" status

### Pending Children Management
- **Immediate visibility** - Pending children appear in all family lists instantly
- **Status indicators** - Shows "Invite not accepted" status in UI
- **Full management** - Parents can delete, reissue invitations, and add photos
- **Map integration** - Map starts listening for pending children immediately
- **No expiry** - Pending invitations never expire
- **ID continuity** - Map connection preserved when child accepts invitation
- **Debug logging** - Comprehensive logs for troubleshooting ID replacement

### Invitation Acceptance
- Validates invite code and expiration
- Handles both new and existing child accounts
- **For pending children**: Replaces pending child UUID with authenticated user ID (preserves map connection)
- **For accepted children**: Deletes old child and creates new with authenticated user ID
- Updates child's name in user document
- Marks invitation as used

### Invitation Reissuing
- **Smart duplicate prevention** - Updates existing pending child instead of creating duplicates
- **Invalidates old invitations** - Marks previous invitation codes as used
- **Generates new codes** - Creates fresh invitation codes for pending children
- **Maintains child data** - Preserves photos, names, and other child information

### Welcome Flow
- Shows "Setting up account..." message during processing
- Transitions to welcome message after 2.5 seconds
- Provides smooth user experience during Cloud Function execution
- **Forces immediate location update** - Child appears on parent map immediately after tapping "Next"

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
    // Triggers forceLocationUpdate after invitation acceptance
}
```

### LocationService.swift
```swift
class LocationService: ObservableObject {
    // Forces immediate location update to Firestore
    func forceLocationUpdate() {
        // Uses current location if available, otherwise requests fresh location
        // Writes to Firestore immediately so parent map shows child instantly
    }
}
```

### Cloud Functions (functions/index.js)
```javascript
// createInvitation - Creates invitations and pending children
exports.createInvitation = onCall(async (data, context) => {
  // Validates parent permissions
  // Checks for existing pending children (prevents duplicates)
  // Creates invitation document
  // Creates pending child as FamilyMember with status: "pending"
  // Handles reissuing for existing pending children
});

// acceptInvitation - Processes invitation acceptance
exports.acceptInvitation = onCall(async (data, context) => {
  // Validates invitation
  // For pending children: Replaces UUID with authenticated user ID
  // For accepted children: Deletes old child and creates new with authenticated user ID
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
      joinedAt: timestamp,
      status: "accepted" // Default for existing members
    },
    "childUserId": {
      role: "child", 
      name: "Emma",
      joinedAt: timestamp,
      status: "accepted" // Accepted child
    },
    "pendingChildId": {
      role: "child",
      name: "Dracula",
      joinedAt: timestamp,
      status: "pending", // Pending child - appears in lists immediately
      imageURL: null,
      imageBase64: null,
      hasImage: false
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
6. **Pending Child Analytics** - Track invitation acceptance rates
7. **Auto-cleanup** - Remove old pending children after extended periods

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
5. **Pending children not appearing** - Check family listener and getAllChildren() method
6. **Duplicate pending children** - Verify reissue logic in createInvitation Cloud Function
7. **"Cannot access 'inviteCode' before initialization"** - Check variable declaration order in Cloud Function
8. **Map not showing accepted children** - Verify ID replacement in acceptInvitation Cloud Function
9. **New children don't appear on parent map immediately** - Check forceLocationUpdate() is called after invitation acceptance
10. **"No ObservableObject of type LocationService found"** - Verify LocationService is injected throughout view hierarchy

### Debug Steps
1. Check Cloud Function logs: `firebase functions:log --only createInvitation`
2. Check Cloud Function logs: `firebase functions:log --only acceptInvitation`
3. Verify Firestore documents exist and have correct data
4. Check user authentication status
5. Validate invitation code format and expiration
6. Check family.members for pending children with status: "pending"
7. Verify ChildDisplayItem.isPending logic in FamilyModels.swift
8. **For map issues**: Verify that map listens to authenticated user ID, not pending UUID
9. **For ID replacement**: Check logs for "Replacing pending child ID with authenticated user ID"
10. **For immediate map visibility**: Check console for "📍 Force location update requested" after invitation acceptance
11. **For environment object issues**: Verify LocationService is injected in WelcomeView, AuthenticationView, and ChildSignUpView

## Pending Invitations Implementation

### Overview
The pending invitations feature allows parents to create invitations that immediately create a "pending child" in the family. This child appears in all family lists with "Invite not accepted" status, allowing parents to manage them (delete, reissue invitations, add photos) before the child accepts the invitation.

### Key Implementation Details

#### 1. FamilyMember Model Enhancement
```swift
struct FamilyMember: Codable, Equatable {
    let role: FamilyRole
    let name: String
    let joinedAt: Date
    let imageURL: String?
    let imageBase64: String?
    let hasImage: Bool?
    let status: InvitationStatus // New field: "pending" or "accepted"
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        // ... existing fields ...
        status = try container.decodeIfPresent(InvitationStatus.self, forKey: .status) ?? .accepted
    }
}
```

#### 2. ChildDisplayItem Integration
```swift
struct ChildDisplayItem: Identifiable {
    let id: String
    let name: String
    let role: FamilyRole
    let joinedAt: Date
    let imageBase64: String?
    let status: InvitationStatus
    let isPending: Bool // Derived from status
    
    init(from familyMember: FamilyMember, id: String) {
        // ... existing fields ...
        self.status = familyMember.status
        self.isPending = familyMember.status == .pending
    }
}
```

#### 3. Cloud Function Logic
The `createInvitation` Cloud Function now:
- Checks for existing pending children with the same name
- If found, reissues invitation (invalidates old, creates new) without creating duplicates
- If not found, creates new pending child as FamilyMember with status: "pending"
- Uses batch operations for atomicity

#### 4. UI Integration
- `ChildProfileView` handles both pending and accepted children
- Dynamic button labels: "Reissue Invitation" vs "Generate New Invitation Code"
- Status indicators show "Invite not accepted" for pending children
- All existing functionality (delete, photos, etc.) works for pending children

#### 5. Map Integration
- `ParentMapViewModel` listens for all children (pending and accepted)
- Pending children are included in `getAllChildrenIds()` for location monitoring
- Map starts listening immediately when pending child is created

### Benefits
1. **Immediate Feedback** - Parents see pending children instantly
2. **Full Management** - Can manage pending children like accepted ones
3. **No Duplicates** - Smart reissue logic prevents duplicate pending children
4. **Consistent UI** - Same interface for pending and accepted children
5. **Map Ready** - Location tracking starts immediately for pending children
6. **Backward Compatible** - Existing children default to "accepted" status
7. **Immediate Map Visibility** - New children appear on parent map instantly after invitation acceptance
8. **Data Preservation** - Profile photos and other data preserved when reissuing invitations
