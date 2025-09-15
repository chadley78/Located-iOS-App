# Located App - User Flow Diagram

## App Entry Points
```
App Launch
    ↓
┌─────────────────┐
│   Splash Screen │
│   (Located Logo)│
└─────────────────┘
    ↓
┌─────────────────┐
│ Authentication  │
│   Check Screen  │
└─────────────────┘
    ↓
    ├─ User Logged In? ── YES ──→ Main App Flow
    │
    └─ NO ──→ Authentication Flow
```

## Authentication Flow
```
Authentication Flow
    ↓
┌─────────────────┐
│   Welcome Screen│
│  "Keep your kids│
│   safe & sound" │
└─────────────────┘
    ↓
    ├─ Parent ──→ Parent Sign Up/Login
    │
    └─ Child ──→ Child Sign Up/Login
```

## Parent Authentication Flow
```
Parent Sign Up/Login
    ↓
┌─────────────────┐
│ Parent Login    │
│ [Email]         │
│ [Password]      │
│ [Login Button]  │
│ [Sign Up Link]  │
└─────────────────┘
    ↓
┌─────────────────┐
│ Parent Sign Up  │
│ [Name]          │
│ [Email]         │
│ [Password]      │
│ [Confirm Pass]  │
│ [Create Account]│
└─────────────────┘
    ↓
┌─────────────────┐
│ Parent Onboarding│
│ "Add your child" │
│ [Add Child Btn] │
└─────────────────┘
    ↓
┌─────────────────┐
│ Invite Child    │
│ [Generate Code] │
│ [Share Code]    │
│ [QR Code]       │
└─────────────────┘
```

## Child Authentication Flow
```
Child Sign Up/Login
    ↓
┌─────────────────┐
│ Child Login     │
│ [Email]         │
│ [Password]      │
│ [Login Button]  │
│ [Sign Up Link]  │
└─────────────────┘
    ↓
┌─────────────────┐
│ Child Sign Up   │
│ [Name]          │
│ [Email]         │
│ [Password]      │
│ [Confirm Pass]  │
│ [Create Account]│
└─────────────────┘
    ↓
┌─────────────────┐
│ Accept Invitation│
│ [Enter Code]    │
│ [Accept Button] │
└─────────────────┘
    ↓
┌─────────────────┐
│ Permission Setup│
│ [Location Always]│
│ [Notifications] │
│ [Continue]      │
└─────────────────┘
```

## Main App Flows

### Parent Main Flow
```
Parent Main App
    ↓
┌─────────────────┐
│ Parent Home     │
│ [Map View]      │
│ [Child Location]│
│ [Geofences]     │
│ [Settings]      │
└─────────────────┘
    ↓
    ├─ View Child Location ──→ Map Detail
    │
    ├─ Manage Geofences ──→ Geofence Management
    │
    └─ Settings ──→ Parent Settings
```

### Child Main Flow
```
Child Main App
    ↓
┌─────────────────┐
│ Child Home      │
│ [Status: Active]│
│ [Location: On]  │
│ [Parents: 2]    │
│ [Settings]      │
└─────────────────┘
    ↓
    ├─ View Status ──→ Detailed Status
    │
    └─ Settings ──→ Child Settings
```

## Geofence Management Flow
```
Geofence Management
    ↓
┌─────────────────┐
│ Geofence List  │
│ [Add New]       │
│ [School ✓]      │
│ [Home ✓]        │
│ [Park ✓]        │
└─────────────────┘
    ↓
┌─────────────────┐
│ Create Geofence │
│ [Map View]       │
│ [Pin Location]  │
│ [Set Radius]    │
│ [Name: School]  │
│ [Save]          │
└─────────────────┘
```

## Notification Flow
```
Geofence Event
    ↓
┌─────────────────┐
│ Child Enters/   │
│ Exits Geofence  │
│ [Event Logged]  │
└─────────────────┘
    ↓
┌─────────────────┐
│ Cloud Function  │
│ [Triggered]     │
└─────────────────┘
    ↓
┌─────────────────┐
│ Parent Gets     │
│ Push Notification│
│ "Alex left School"│
└─────────────────┘
```

## Key User Flows Summary

1. **Onboarding Flow**: Welcome → Choose Role → Sign Up/Login → Setup
2. **Parent Flow**: Login → Add Child → Create Geofences → Monitor
3. **Child Flow**: Login → Accept Invitation → Grant Permissions → Status
4. **Geofence Flow**: Create → Monitor → Notify → Manage
5. **Settings Flow**: Profile → Permissions → Notifications → Privacy

## Screen Categories

### Authentication Screens (6 screens)
- Welcome/Splash
- Parent Login
- Parent Sign Up
- Child Login
- Child Sign Up
- Permission Setup

### Parent Screens (5 screens)
- Parent Home (Map)
- Invite Child
- Geofence List
- Create Geofence
- Parent Settings

### Child Screens (3 screens)
- Child Home (Status)
- Accept Invitation
- Child Settings

### Shared Screens (2 screens)
- Profile Management
- Notification Settings

**Total: 16 screens to design**

