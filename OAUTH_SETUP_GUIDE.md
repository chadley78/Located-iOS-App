# OAuth Sign-In Setup Guide

This guide covers the manual configuration steps needed to complete the Apple and Google sign-in setup for the Located app.

## ✅ Completed Code Changes

The following code changes have been implemented:
- ✅ Added GoogleSignIn pod to Podfile and installed dependencies
- ✅ Added OAuth authentication methods to AuthenticationService.swift
- ✅ Added Google and Apple sign-in buttons to SignInView (parent flow only)
- ✅ Added Google and Apple sign-up buttons to SignUpView (parent flow only)
- ✅ Configured Google Sign-In URL callback handling in LocatedAppApp.swift

## 🔧 Required Manual Configuration

### 1. Firebase Console Setup

**Google Sign-In:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `located-d9dce`
3. Navigate to **Authentication** > **Sign-in method**
4. Click on **Google** and toggle it to **Enabled**
5. Click **Save**

**Apple Sign-In:**
1. In the same **Sign-in method** section
2. Click on **Apple**
3. Toggle it to **Enabled**
4. You'll need to provide:
   - **Team ID**: Find this in your Apple Developer account (top right corner)
   - **Bundle ID**: `com.zimplify.located`
5. Click **Save**

### 2. Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click on **Identifiers**
4. Select your app identifier: `com.zimplify.located`
5. Scroll down and check **Sign in with Apple**
6. Click **Save** in the top right

### 3. Google Cloud Console - OAuth Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select the project linked to your Firebase project
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth 2.0 Client ID**
5. Select **iOS** as the application type
6. Configure:
   - **Name**: Located iOS App
   - **Bundle ID**: `com.zimplify.located`
7. Click **Create**
8. Download the updated `GoogleService-Info.plist` from Firebase Console (it should now include the `REVERSED_CLIENT_ID`)

### 4. Update GoogleService-Info.plist

1. Download the fresh `GoogleService-Info.plist` from Firebase Console:
   - Firebase Console > Project Settings > General
   - Scroll to "Your apps" section
   - Click the download button for iOS app
2. Replace the existing file in Xcode:
   - Open `LocatedApp.xcworkspace` in Xcode
   - Locate `GoogleService-Info.plist` in the project navigator
   - Delete the old file (Move to Trash)
   - Drag the new file into the project
   - Make sure "Copy items if needed" is checked
   - Select LocatedApp target

### 5. Xcode Configuration

**Add Sign in with Apple Capability:**
1. Open `LocatedApp.xcworkspace` in Xcode
2. Select the **LocatedApp** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Search for and add **Sign in with Apple**

**Configure URL Schemes for Google Sign-In:**
1. Still in Xcode, select the **LocatedApp** target
2. Go to the **Info** tab
3. Expand **URL Types** section
4. Click the **+** button to add a new URL Type
5. In **URL Schemes**, add the `REVERSED_CLIENT_ID` from your updated `GoogleService-Info.plist`
   - It should look like: `com.googleusercontent.apps.987791360749-xxxxxxxxxx`
   - Find this value in the plist under the key `REVERSED_CLIENT_ID`
6. Leave **Identifier** blank or use your bundle ID
7. Set **Role** to **Editor**

## 🧪 Testing

Once all configuration is complete, test the following:

### New User Sign-Up (Parent)
1. Open the app and select "I'm a Parent"
2. Try "Continue with Google" button
3. Verify Google OAuth flow completes
4. Check that user profile is created in Firestore with Google display name
5. Try "Continue with Apple" button
6. Verify Apple Sign In flow completes
7. Check that user profile is created with Apple display name

### Existing User Sign-In
1. Create a parent account using email/password
2. Sign out
3. Try signing in with Google using the same email
4. Verify that the OAuth provider is linked to the existing account
5. Sign out and sign in with Google again - should work seamlessly

### Account Linking
1. Sign in with email/password
2. Go to profile/settings (when implemented)
3. Link Google/Apple account
4. Verify you can now sign in with any linked method

## 🔍 Troubleshooting

**Google Sign-In fails:**
- Verify `GoogleService-Info.plist` has `REVERSED_CLIENT_ID`
- Check that URL Scheme is configured correctly in Xcode
- Ensure OAuth Client ID is created in Google Cloud Console
- Check Firebase Console has Google sign-in enabled

**Apple Sign In fails:**
- Verify "Sign in with Apple" capability is added in Xcode
- Check Apple Developer Portal has the capability enabled
- Ensure Firebase Console has Apple sign-in enabled with correct Team ID
- Make sure you're testing on a real device (not simulator for some Apple ID features)

**Account linking fails:**
- Check Firebase Console > Authentication > Settings > User account linking
- Verify email addresses match between OAuth provider and existing account
- Check console logs for specific error messages

## 📝 Bundle ID Reference

The app bundle ID is: **`com.zimplify.located`**

Use this consistently across:
- Firebase Console
- Apple Developer Portal
- Google Cloud Console
- Xcode project settings

## 🔐 Security Notes

- The OAuth implementation includes account linking to prevent duplicate accounts
- Users who sign up with email/password can later link Google/Apple
- Users who sign in with Google/Apple will have those providers linked automatically
- FCM token is registered after successful OAuth sign-in for notifications

