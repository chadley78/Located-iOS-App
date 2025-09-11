# Located - Child Safety Location App

A native iOS application that provides 'always on' location tracking and geofencing notifications for child safety.

## 🎯 Project Overview

Located is a comprehensive child safety app built with SwiftUI and Firebase that allows parents to track their children's locations in real-time and receive notifications when they enter or exit designated safe zones (geofences).

## 🚀 Features Implemented

### ✅ Phase 1: Project Setup & Core Backend
- [x] **BE-01**: Firebase Project Setup with Firestore, Authentication, and Cloud Functions
- [x] **BE-02**: Firestore Database Structure and Security Rules

### ✅ Phase 2: UI/UX Design & App Scaffolding  
- [x] **DS-01**: Onboarding, Authentication, and Home Screen UI/UX Design
- [x] **IOS-01**: iOS Project Setup with User Authentication

### ✅ Phase 3: 'Always On' Location Tracking
- [x] **IOS-02**: Child Location Sharing via Core Location Background Updates
- [x] **IOS-03**: Parent Map View for Live Tracking with MapKit

## 🛠 Technology Stack

- **Language**: Swift
- **Framework**: SwiftUI
- **Backend**: Google Firebase
  - Authentication (Email/Password)
  - Firestore Database
  - Cloud Functions
- **Mapping**: Apple MapKit
- **Location Services**: Core Location with Background Updates

## 📱 App Architecture

### User Types
- **Parent**: Can view children's locations on a map, create geofences, receive notifications
- **Child**: Shares location data in background, receives geofence notifications

### Key Components
- **AuthenticationService**: Handles user registration, login, and session management
- **LocationService**: Manages location tracking and Firestore integration
- **BackgroundLocationManager**: Handles background location updates
- **ParentMapView**: Real-time map display with child location annotations

## 🔐 Security & Privacy

- **Firebase Authentication**: Secure user accounts for both parents and children
- **Firestore Security Rules**: Enforce data access permissions
- **Location Permissions**: Clear justifications for 'Always Allow' location access
- **Data Privacy**: Location data only accessible to authorized parents

## 📋 Current Status

The app currently supports:
- User registration and authentication for both parents and children
- Real-time location tracking with background updates
- Parent map view showing children's locations
- Location data storage in Firestore
- Proper iOS permissions and background modes

## 🚧 Next Steps

### Phase 4: Geofencing & Notifications
- [ ] **BE-03**: Firebase Cloud Function for Push Notifications
- [ ] **IOS-04**: Geofence Creation and Monitoring
- [ ] **IOS-05**: Push Notification Implementation

### Phase 5: Testing and Finalization
- [ ] **QA-01**: Comprehensive Test Plan Development

## 🏗 Project Structure

```
LocatedApp/
├── LocatedApp/
│   ├── LocatedAppApp.swift          # Main app entry point
│   ├── ContentView.swift            # Main UI and navigation
│   ├── AuthenticationService.swift   # Firebase authentication
│   ├── LocationService.swift         # Location tracking logic
│   ├── BackgroundLocationManager.swift # Background location handling
│   ├── GoogleService-Info.plist     # Firebase configuration
│   └── Info.plist                   # App configuration
├── LocatedApp.xcodeproj/            # Xcode project file
└── Pods/                            # CocoaPods dependencies
```

## 🔧 Setup Instructions

1. **Clone the repository**
2. **Open `LocatedApp.xcworkspace`** in Xcode
3. **Install dependencies**: `pod install` (if needed)
4. **Configure Firebase**:
   - Replace `GoogleService-Info.plist` with your Firebase project configuration
   - Update bundle identifier to match your Firebase app
5. **Build and run** on iOS Simulator or device

## 📄 License

This project is part of a development exercise and is not intended for production use without proper security review and testing.

## 🤝 Contributing

This is a sequential development project following specific task requirements. Please refer to `Tasks.json` for the complete development plan.

---

**Note**: This app requires proper Firebase project setup and iOS developer account for full functionality including push notifications and App Store distribution.
