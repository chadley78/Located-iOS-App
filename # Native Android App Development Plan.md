# Native Android App Development Plan

## Overview

Build a native Android app using Kotlin and Jetpack Compose that mirrors the functionality of your existing iOS Swift app. This ensures maximum performance, battery efficiency, and platform integration for location tracking features.

## Architecture

### Technology Stack

- **Language:** Kotlin
- **UI Framework:** Jetpack Compose (Modern Android UI, similar to SwiftUI)
- **Architecture:** MVVM (Model-View-ViewModel) with Clean Architecture
- **Dependency Injection:** Hilt (Google's recommended DI for Android)
- **Backend:** Firebase (Firestore, Auth, Cloud Messaging, Functions)
- **Subscriptions:** RevenueCat Android SDK
- **Maps:** Google Maps Android SDK
- **Location Services:** Android Location Services + WorkManager for background tasks

### Project Structure

```
LocatedAndroid/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/located/app/
│   │   │   │   ├── data/
│   │   │   │   │   ├── model/          # Data classes (Family, User, Location, Geofence)
│   │   │   │   │   ├── repository/     # Data layer
│   │   │   │   │   └── local/          # Room database for caching
│   │   │   │   ├── domain/
│   │   │   │   │   ├── usecase/        # Business logic
│   │   │   │   │   └── repository/     # Repository interfaces
│   │   │   │   ├── presentation/
│   │   │   │   │   ├── auth/           # Login/SignUp screens
│   │   │   │   │   ├── family/         # Family management
│   │   │   │   │   ├── map/            # Map view
│   │   │   │   │   ├── geofence/       # Geofence management
│   │   │   │   │   └── subscription/   # Subscription/paywall
│   │   │   │   ├── service/
│   │   │   │   │   ├── LocationService.kt        # Foreground service for location
│   │   │   │   │   ├── GeofenceService.kt        # Geofence monitoring
│   │   │   │   │   └── LocationWorker.kt         # Background WorkManager
│   │   │   │   ├── util/
│   │   │   │   │   ├── Constants.kt
│   │   │   │   │   └── Extensions.kt
│   │   │   │   └── LocatedApplication.kt
│   │   │   ├── res/
│   │   │   └── AndroidManifest.xml
│   │   └── test/
│   └── build.gradle.kts
└── build.gradle.kts
```

## Implementation Phases

### Phase 1: Project Setup & Authentication

**Files to create:**

- `build.gradle.kts` (Project & App level)
- `LocatedApplication.kt` - App entry point
- `data/model/User.kt` - User data model
- `data/model/Family.kt` - Family data model
- `data/repository/AuthRepository.kt` - Authentication logic
- `presentation/auth/AuthViewModel.kt` - Auth state management
- `presentation/auth/WelcomeScreen.kt` - Welcome/login UI
- `presentation/auth/LoginScreen.kt` - Email/password + Google Sign-In

**Key Android-specific considerations:**

- Use Firebase Auth with Google Sign-In (configure SHA-1 certificate)
- Handle Android Activity lifecycle correctly
- Store auth tokens securely using EncryptedSharedPreferences

**iOS equivalent files:**

- `AuthenticationService.swift` → `AuthRepository.kt`
- `WelcomeView` (SwiftUI) → `WelcomeScreen.kt` (Compose)
- Google Sign-In already configured in your iOS app

---

### Phase 2: Firebase Integration & Family System

**Files to create:**

- `data/model/FamilyMember.kt` - Family member model
- `data/model/FamilyRole.kt` - Parent/child roles enum
- `data/model/Invitation.kt` - Invitation model
- `data/repository/FamilyRepository.kt` - Family CRUD operations
- `data/repository/InvitationRepository.kt` - Invitation handling
- `presentation/family/FamilyViewModel.kt` - Family state management
- `presentation/family/CreateFamilyScreen.kt` - Family creation UI
- `presentation/family/InviteMemberScreen.kt` - Generate invitation codes
- `presentation/family/JoinFamilyScreen.kt` - Accept invitations

**Key implementation details:**

- Reuse existing Firestore structure (families, users, invitations collections)
- Reuse existing Firestore security rules (no backend changes needed)
- Handle deep links for invitation codes (`located://invite/CODE`)
- Implement real-time listeners for family member updates

**iOS equivalent files:**

- `FamilyModels.swift` → Multiple model files in `data/model/`
- `FamilyService.swift` → `FamilyRepository.kt`
- `FamilyInvitationService.swift` → `InvitationRepository.kt`
- `FamilyViews.swift` → Multiple screen files in `presentation/family/`

---

### Phase 3: Location Tracking & Background Service

**Files to create:**

- `data/model/LocationData.kt` - Location data model
- `data/repository/LocationRepository.kt` - Save locations to Firestore
- `service/LocationService.kt` - Foreground service with persistent notification
- `service/LocationWorker.kt` - WorkManager for periodic updates
- `util/LocationPermissionHelper.kt` - Permission request utilities
- `presentation/location/LocationPermissionScreen.kt` - Permission request UI

**Key Android-specific implementation:**

- **Foreground Service:** Required for background location on Android 8+
  - Must display persistent notification ("Located is tracking location")
  - Use `startForegroundService()` and `startForeground()`
- **Permissions:** Request `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
  - Background permission requires separate request (Android 10+)
- **WorkManager:** Schedule periodic location updates when app is not in foreground
- **Battery optimization:** Request exemption from Doze mode for critical tracking
- **Location updates:** Use `FusedLocationProviderClient` (Google Play Services)
  - Configure update interval (10-30 seconds when moving)
  - Use high accuracy mode for precision

**iOS equivalent files:**

- `LocationData` struct → `LocationData.kt`
- `LocationService.swift` → `LocationService.kt` + `LocationWorker.kt`
- iOS uses "Always Allow" permission → Android uses foreground + background permissions

**Critical differences from iOS:**

- iOS: Background location "just works" with Always permission
- Android: Requires foreground service with notification + WorkManager

---

### Phase 4: Geofencing & Notifications

**Files to create:**

- `data/model/Geofence.kt` - Geofence data model
- `data/model/GeofenceEvent.kt` - Geofence event model
- `data/repository/GeofenceRepository.kt` - Geofence CRUD
- `service/GeofenceService.kt` - Android Geofencing API integration
- `receiver/GeofenceBroadcastReceiver.kt` - Handle geofence transitions
- `service/NotificationService.kt` - Firebase Cloud Messaging
- `presentation/geofence/CreateGeofenceScreen.kt` - Draw geofence on map
- `presentation/geofence/GeofenceListScreen.kt` - Manage geofences

**Key Android-specific implementation:**

- **Geofencing API:** Use `GeofencingClient` from Google Play Services
  - Register geofences with lat/lng/radius
  - Receive enter/exit events via PendingIntent → BroadcastReceiver
- **Firebase Cloud Messaging (FCM):** 
  - Configure `google-services.json` from Firebase Console
  - Handle notification display in foreground/background
  - Use notification channels (Android 8+) for user control
- **Notification permissions:** Request `POST_NOTIFICATIONS` (Android 13+)

**iOS equivalent files:**

- `GeofenceService.swift` → `GeofenceService.kt` + `GeofenceBroadcastReceiver.kt`
- `GeofenceManagementView.swift` → `GeofenceListScreen.kt`
- `CreateGeofenceView.swift` → `CreateGeofenceScreen.kt`
- `NotificationService.swift` → `NotificationService.kt`

**Reuse from iOS:**

- Cloud Functions (`functions/index.js`) - no changes needed
- Firestore structure (geofences, geofence_events collections)

---

### Phase 5: Map Interface & Real-time Updates

**Files to create:**

- `presentation/map/MapScreen.kt` - Main map view
- `presentation/map/MapViewModel.kt` - Real-time location updates
- `util/MapUtils.kt` - Map helper functions
- `presentation/map/MemberMarker.kt` - Custom map markers

**Key Android-specific implementation:**

- **Google Maps Android SDK:** 
  - Requires API key in `AndroidManifest.xml`
  - Use `MapView` composable in Jetpack Compose
  - Add custom markers for family members
- **Real-time updates:** 
  - Listen to Firestore `locations` collection
  - Update markers as child locations change
- **Map features:**
  - Show geofences as circles
  - Display location history as polylines
  - Center on family members

**iOS equivalent files:**

- `ContentView.swift` (map section) → `MapScreen.kt`
- Uses MapKit → Android uses Google Maps SDK
- Same Firestore listeners for real-time updates

---

### Phase 6: Subscription & Paywall (RevenueCat)

**Files to create:**

- `data/model/SubscriptionInfo.kt` - Subscription models
- `data/repository/SubscriptionRepository.kt` - RevenueCat integration
- `presentation/subscription/PaywallScreen.kt` - Subscription UI
- `presentation/subscription/SubscriptionViewModel.kt` - State management
- `presentation/subscription/SubscriptionGate.kt` - Feature gating

**Key Android-specific implementation:**

- **RevenueCat Android SDK:**
  - Configure with same project/API key as iOS
  - Use `Purchases.configure()` in Application class
  - Handle Android-specific billing flows
- **Google Play Billing:**
  - Create subscription products in Google Play Console
  - Link to RevenueCat dashboard
  - Test with license testers
- **7-day trial:** Configure in RevenueCat + Google Play
- **Family-based subscription:** Same logic as iOS (only creator pays)

**iOS equivalent files:**

- `SubscriptionService.swift` → `SubscriptionRepository.kt`
- `PaywallView.swift` → `PaywallScreen.kt`
- `SubscriptionGate.swift` → `SubscriptionGate.kt`

**Reuse from iOS:**

- RevenueCat project and configuration
- Firestore subscription sync logic
- Trial period management

---

### Phase 7: UI Polish & App Distribution

**Files to create:**

- `presentation/theme/Theme.kt` - Material Design 3 theme
- `presentation/theme/Color.kt` - Color palette matching iOS
- `presentation/theme/Typography.kt` - Font styles
- `presentation/components/` - Reusable UI components
- `res/drawable/` - Icons and assets
- App icons and splash screen

**Android-specific tasks:**

- **Material Design 3:** Follow Android design guidelines
  - Use Material You dynamic colors (optional)
  - Implement bottom navigation
  - Add floating action buttons where appropriate
- **Adaptive icons:** Create icon for different Android launchers
- **App signing:** Generate keystore for release builds
- **Google Play Console setup:**
  - Create app listing
  - Add screenshots (phone + tablet)
  - Write store description
  - Configure pricing & distribution
- **Privacy policy:** Link to same policy as iOS
- **Permissions justification:** Explain background location in store listing

**iOS equivalent:**

- `AppColors.swift`, `AppTypography.swift` → Theme files
- App Store Connect → Google Play Console
- TestFlight → Internal testing track

---

## Key Dependencies (build.gradle.kts)

```kotlin
dependencies {
    // Jetpack Compose
    implementation("androidx.compose.ui:ui:1.6.0")
    implementation("androidx.compose.material3:material3:1.2.0")
    
    // Firebase
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-messaging-ktx")
    
    // Google Sign-In
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    
    // Google Maps & Location
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.1.0")
    
    // RevenueCat
    implementation("com.revenuecat.purchases:purchases:7.5.0")
    
    // Hilt (Dependency Injection)
    implementation("com.google.dagger:hilt-android:2.50")
    kapt("com.google.dagger:hilt-compiler:2.50")
    
    // WorkManager
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // Compose Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")
    
    // Coil (Image loading)
    implementation("io.coil-kt:coil-compose:2.5.0")
}
```

## Android-Specific Permissions (AndroidManifest.xml)

```xml
<!-- Location permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Foreground service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Wake locks for background work -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Boot receiver (restart location service after reboot) -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

## Critical Implementation Notes

### Background Location on Android

Unlike iOS, Android requires explicit user consent and system integration:

1. **Foreground Service:** Display persistent notification showing app is tracking
2. **Background Permission:** Separate permission dialog explaining why you need it
3. **Battery Optimization:** Request to disable battery optimization for the app
4. **Doze Mode:** Use WorkManager to work around Android's aggressive battery saving

### Testing Strategy

1. **Emulator testing:** Use Android Studio emulator with mock locations
2. **Physical device testing:** Test on real devices (different manufacturers behave differently)
3. **Background behavior:** Test with screen off, app killed, phone restarted
4. **Battery impact:** Monitor battery drain over 24 hours
5. **Geofence accuracy:** Test different radii and transition delays

### Code Reuse

- ✅ **Backend:** 100% reused (Firebase Functions, Firestore rules)
- ✅ **Data structure:** 100% reused (same Firestore collections)
- ✅ **Business logic:** Replicated in Kotlin (similar patterns)
- ❌ **UI code:** 0% reused (SwiftUI → Jetpack Compose)

### Estimated Timeline

- **Phase 1-2:** 2-3 weeks (Auth + Family system)
- **Phase 3:** 2-3 weeks (Location tracking - most complex)
- **Phase 4:** 1-2 weeks (Geofencing + Notifications)
- **Phase 5:** 1 week (Map interface)
- **Phase 6:** 1 week (Subscriptions)
- **Phase 7:** 1 week (Polish + store listing)

**Total:** 8-12 weeks for feature parity with iOS app

## Files That Will Be Created

### Core Application

- `LocatedApplication.kt` - Application entry point
- `MainActivity.kt` - Single activity with Compose navigation
- `app/build.gradle.kts` - Dependencies and configuration
- `AndroidManifest.xml` - Permissions and services

### Data Layer (~15 files)

- Models: `User.kt`, `Family.kt`, `FamilyMember.kt`, `Location.kt`, `Geofence.kt`, `GeofenceEvent.kt`, `Invitation.kt`, `Subscription.kt`
- Repositories: `AuthRepository.kt`, `FamilyRepository.kt`, `LocationRepository.kt`, `GeofenceRepository.kt`, `SubscriptionRepository.kt`

### Services (~5 files)

- `LocationService.kt` - Foreground service
- `LocationWorker.kt` - Background worker
- `GeofenceService.kt` - Geofence monitoring
- `NotificationService.kt` - FCM handler
- `GeofenceBroadcastReceiver.kt` - Geofence events

### Presentation Layer (~25 files)

- Authentication screens (3 files)
- Family management screens (5 files)
- Map screens (3 files)
- Geofence screens (4 files)
- Subscription screens (3 files)
- Profile/settings screens (3 files)
- Shared components (4 files)

### Resources

- Themes, colors, typography
- Drawables (icons, logos)
- Strings (localization)

**Total:** ~50-60 new Kotlin files

## Next Steps

Once this plan is approved, I will:

1. Generate Android project structure with Gradle configuration
2. Set up Firebase configuration (`google-services.json`)
3. Implement authentication system first (foundation for everything else)
4. Build incrementally, testing each phase before moving forward
5. Ensure API parity with iOS at every step