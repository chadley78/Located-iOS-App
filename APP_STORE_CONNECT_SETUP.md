# App Store Connect & Sandbox Testing Setup

Complete guide to set up subscriptions in App Store Connect and test with sandbox accounts.

## 📱 Part 1: App Store Connect - Create Subscription Product

### Step 1: Login to App Store Connect
1. Go to: https://appstoreconnect.apple.com
2. Sign in with your Apple Developer account
3. Click on **"My Apps"**
4. Select **"Located"** (or create app if it doesn't exist)

### Step 2: Create App if Needed
If Located doesn't exist yet:
1. Click **"+"** → **"New App"**
2. Fill in:
   - **Platforms**: iOS
   - **Name**: Located
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.zimplify.located`
   - **SKU**: located-app (or any unique ID)
   - **User Access**: Full Access
3. Click **"Create"**

### Step 3: Create Subscription Group
1. In your app, go to **"Features"** → **"In-App Purchases"**
2. Click **"+"** next to "Subscription Groups"
3. Create new group:
   - **Reference Name**: `Located Subscriptions`
   - Click **"Create"**

### Step 4: Create Subscription Product
1. Inside the subscription group, click **"+"** (Create Subscription)
2. Fill in **Product Information**:
   - **Reference Name**: `Located Family Subscription`
   - **Product ID**: `located_family_monthly` ⚠️ **MUST MATCH EXACTLY**
   - Click **"Create"**

3. **Subscription Duration**:
   - Select: **1 month**

4. **Subscription Prices**:
   - Click **"Add Subscription Price"**
   - Select **"United States"** (or your region)
   - Price: **$4.99** (or your choice)
   - Click **"Next"** → **"Add"**

5. **Subscription Localizations**:
   - Click **"+"** under Localizations
   - Language: **English (U.S.)**
   - **Display Name**: `Family Plan`
   - **Description**: `Keep your family connected with real-time location tracking and geofence alerts`
   - Click **"Save"**

6. **App Store Review Information**:
   - **Screenshot**: Upload any screenshot (required but won't be reviewed for sandbox)
   - **Review Notes**: "Monthly subscription for family tracking features"

7. Click **"Save"** (top right)

### Step 5: Submit for Review (Optional for Sandbox)
- For **sandbox testing**: You can test immediately without review
- For **production**: Click "Submit for Review" when ready to publish

---

## 🧪 Part 2: Create Sandbox Test Account

### Step 1: Create Sandbox User
1. In App Store Connect, click your name (top right)
2. Go to **"Users and Access"**
3. Click **"Sandbox"** tab
4. Click **"+"** (Add Tester)

### Step 2: Fill in Sandbox Account Details
- **First Name**: Test
- **Last Name**: User
- **Email**: Create a UNIQUE email (e.g., `test.located.001@gmail.com`)
  - ⚠️ Can be fake, but must be unique and not used before
  - ⚠️ Don't use your real Apple ID
- **Password**: Create a password (you'll need to remember it)
- **Country/Region**: United States (or your region)
- Click **"Invite"**

### Step 3: Save Credentials
**Write these down - you'll need them!**
```
Email: test.located.001@gmail.com
Password: [your chosen password]
```

---

## 🔗 Part 3: Link Product to RevenueCat

### Step 1: Go to RevenueCat Dashboard
1. https://app.revenuecat.com
2. Go to **"Products"** (left sidebar)

### Step 2: Configure Product
1. Find or create product: `located_family_monthly`
2. Click **"App Store"** tab
3. Click **"Link Product"** or **"Edit"**
4. **App Store Product ID**: `located_family_monthly`
5. Click **"Save"**

### Step 3: Configure Entitlement
1. Go to **"Entitlements"** (left sidebar)
2. Create or edit entitlement: **"premium"**
3. **Attach Products**:
   - Add `located_family_monthly` to this entitlement
4. Click **"Save"**

### Step 4: Configure Offering
1. Go to **"Offerings"** (left sidebar)
2. Edit **"default"** offering
3. **Add Package**:
   - Package ID: `$rc_monthly` (or custom name)
   - Product: Select `located_family_monthly`
   - Position: 1
4. Click **"Save"**

---

## 📱 Part 4: Test Purchase on Device

### Step 1: Sign Out of Real Apple ID (Important!)
1. On your iPhone, go to **Settings**
2. Tap your name at top
3. Scroll down → **"Sign Out"**
4. **Important**: Or just sign out of App Store specifically:
   - Settings → App Store → Tap your Apple ID → Sign Out

### Step 2: Sign In with Sandbox Account
1. **Settings** → **App Store**
2. Tap **"Sign In"**
3. Enter your **sandbox account credentials**:
   - Email: `test.located.001@gmail.com`
   - Password: [your password]

### Step 3: Run the App
1. Build and run Located app from Xcode
2. Navigate to **Settings** → **Subscription**
3. Tap **"Subscribe Now"**
4. You should see the paywall with pricing

### Step 4: Make Test Purchase
1. Tap **"Subscribe"** button on the package
2. System will prompt to confirm purchase
3. Use Touch ID/Face ID or password
4. **Sandbox dialog will say**: "[Environment: Sandbox]"
5. Confirm purchase

### Step 5: Check Results

**In App:**
- ✅ Paywall should dismiss
- ✅ Settings shows "Active" subscription
- ✅ App has full access

**In Console Logs:**
```
✅ Purchase successful
🔐 Processing customer info
✅ Subscription active: active, expires: [date]
✅ Subscription synced to Firestore
```

**In RevenueCat Dashboard:**
1. Go to **Customers**
2. Search for your user ID
3. User should now appear in **"Active"** category
4. Click to see:
   - **Overview**: Shows active subscription
   - **Entitlements**: "premium" is active
   - **Attributes**: All your custom data
   - **Purchase History**: Shows the sandbox transaction

---

## 🧪 Testing Different States

Once you have a sandbox subscription:

### Cancel Subscription (Test Canceled State)
1. In RevenueCat Dashboard → Customer page
2. **Refund Purchase** or **Cancel Subscription**
3. Restart app
4. Check dashboard shows "canceled" state

### Test Restoration
1. Delete and reinstall app
2. Sign in again
3. Go to Settings → Subscription
4. Tap **"Restore Purchases"**
5. Subscription should be restored

---

## ⚠️ Important Notes

### Sandbox Purchase Behavior:
- ✅ **Free**: No real money charged
- ✅ **Fast**: Subscriptions renew every 5 minutes (not monthly)
- ✅ **Limited**: Auto-renews 6 times then cancels
- ✅ **Testing**: Perfect for testing subscription lifecycle

### Common Issues:
- **Can't purchase**: Make sure sandbox account is signed in to App Store (not iCloud)
- **Product not found**: Wait 10-15 minutes after creating in App Store Connect
- **Wrong account**: Always use sandbox account, never real Apple ID

---

## 📊 What You'll See at Each Stage

| State | RevenueCat Dashboard | App Behavior |
|-------|---------------------|--------------|
| **Firestore Trial** | No customer visible | Full access |
| **Trial Expired** | No customer visible | Paywall blocks app |
| **After Sandbox Purchase** | Customer appears in "Active" | Full access |
| **Subscription Canceled** | Shows "will not renew" | Access until period ends |
| **Subscription Expired** | Moves to "Expired" | Paywall blocks app |

---

**Start with Step 1 (App Store Connect) and let me know when you've created the subscription product!** I can help you through each step. 🚀

