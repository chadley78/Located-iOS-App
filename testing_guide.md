# Deep Link Testing Guide for Xcode Simulator

## Prerequisites
1. Build and run the LocatedApp in Xcode Simulator
2. Make sure the app is running (not just installed)

## Method 1: Terminal Commands (Recommended)

### Test Deep Link:
```bash
xcrun simctl openurl booted "located://invite/ABC123"
```

### Test Universal Link:
```bash
xcrun simctl openurl booted "https://located.app/invite/ABC123"
```

### Test with Different Codes:
```bash
xcrun simctl openurl booted "located://invite/TEST01"
xcrun simctl openurl booted "located://invite/XYZ789"
```

## Method 2: Safari in Simulator

1. Open Safari in iOS Simulator
2. Type: `located://invite/ABC123`
3. Press Enter
4. App should open with code pre-filled

## Method 3: Complete End-to-End Test

### Step 1: Test Parent Flow
1. Run app in simulator
2. Select "I'm a Parent"
3. Sign up or sign in
4. Create a family
5. Create an invitation
6. Copy the invitation code (e.g., "ABC123")

### Step 2: Test Deep Link
1. Open Terminal
2. Run: `xcrun simctl openurl booted "located://invite/WOME14"`
3. App should open with:
   - "I'm a Child" screen
   - Invitation code pre-filled in the text field
   - Child can enter their name and join family

### Step 3: Test Child Signup Flow
1. With code pre-filled, enter a child name (e.g., "Emma")
2. Tap "Join Family"
3. Should create anonymous account and join family
4. Should see success message and navigate to child home screen

## Method 4: Test URL Parsing

### Test Different URL Formats:
```bash
# Valid formats
xcrun simctl openurl booted "located://invite/ABC123"
xcrun simctl openurl booted "located://invite/TEST01"
xcrun simctl openurl booted "https://located.app/invite/ABC123"

# Invalid formats (should be handled gracefully)
xcrun simctl openurl booted "located://invite/"
xcrun simctl openurl booted "located://invite"
xcrun simctl openurl booted "https://located.app/invite/"
```

## Expected Behavior

### When Deep Link Works:
1. App opens (if not already open)
2. Shows welcome screen
3. When child selects "I'm a Child", code should be pre-filled
4. Child enters name and joins family

### Debug Output to Look For:
```
🔗 Received deep link: located://invite/ABC123
🔗 Extracted invitation code: ABC123
```

## Troubleshooting

### If Deep Link Doesn't Work:
1. Check that app is running in simulator
2. Verify Info.plist has URL scheme configured
3. Check console for error messages
4. Try restarting the simulator

### If Code Isn't Pre-filled:
1. Check that `invitationCode` parameter is being passed correctly
2. Verify `ChildSignUpView` receives the code
3. Check `onAppear` method in `ChildSignUpView`

## Testing Checklist

- [ ] Deep link opens app
- [ ] Code is extracted from URL
- [ ] Code is passed to child signup view
- [ ] Code is pre-filled in text field
- [ ] Child can enter name and join family
- [ ] Anonymous account is created
- [ ] Family membership is established
- [ ] Success message is shown
- [ ] App navigates to child home screen

## Quick Test Commands

```bash
# Test with a real invitation code from your app
xcrun simctl openurl booted "located://invite/YOUR_CODE_HERE"

# Test multiple times
xcrun simctl openurl booted "located://invite/TEST01"
xcrun simctl openurl booted "located://invite/TEST02"
xcrun simctl openurl booted "located://invite/TEST03"
```



