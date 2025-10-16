# Subscription Setup Guide

This guide walks you through setting up RevenueCat subscriptions for the Located app.

## Overview

The Located app uses RevenueCat to manage subscriptions across iOS (and future Android). When a parent creates a family, they automatically get a 7-day free trial. After the trial expires, only the family creator needs to subscribe to continue using the app.

## Prerequisites

### 1. Apple Developer Account Setup

1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. Navigate to **Account** → **Agreements, Tax, and Banking**
4. Complete the **"Paid Applications"** agreement
   - This is required before you can sell in-app purchases
   - You'll need to provide banking information for receiving payments
   - Complete tax forms (W-9 for US developers, W-8BEN for others)

### 2. Create Subscription Product in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Select your app (or create it if it doesn't exist)
3. Navigate to **Features** → **In-App Purchases**
4. Click **+** to create a new in-app purchase
5. Select **Auto-Renewable Subscription**
6. Create a Subscription Group (e.g., "Located Premium")
7. Configure the subscription:
   - **Product ID**: `located_family_monthly` (recommended)
   - **Subscription Duration**: 1 month
   - **Price**: Choose appropriate tier (e.g., $4.99/month)
   - **Subscription Name**: "Located Family Plan"
   - **Description**: "Keep your family connected with real-time location sharing"

8. Add Introductory Offer:
   - Type: **Free Trial**
   - Duration: **7 days**
   - Eligibility: New subscribers only

9. Submit for Review (subscriptions must be approved before going live)

### 3. RevenueCat Setup

#### Create RevenueCat Account

1. Go to [app.revenuecat.com](https://app.revenuecat.com)
2. Create a free account
3. Create a new project named "Located"

#### Add iOS App

1. In RevenueCat dashboard, click **Apps** → **+ New App**
2. Select **iOS/tvOS**
3. Enter your app's Bundle ID (e.g., `com.yourcompany.located`)
4. Name it "Located iOS"

#### Configure Apple App Store

1. In RevenueCat, go to your app's **Settings** → **App Store Connect**
2. Click **Connect to App Store Connect**
3. Generate an App Store Connect API Key:
   - Go to App Store Connect → **Users and Access** → **Keys**
   - Click **+** to generate a new API key
   - Role: **Admin** (or at least **App Manager**)
   - Download the `.p8` key file
   - Note the **Key ID** and **Issuer ID**

4. Upload the API key to RevenueCat:
   - Upload the `.p8` file
   - Enter the Key ID
   - Enter the Issuer ID
   - Enter your Team ID (from Apple Developer Portal)

#### Link Subscription Products

1. In RevenueCat, go to **Products** → **+ New**
2. Select your app
3. Enter the Product ID: `located_family_monthly`
4. RevenueCat will automatically fetch the product details from App Store Connect
5. Create an Entitlement:
   - Go to **Entitlements** → **+ New**
   - Name: `premium`
   - Attach the `located_family_monthly` product to this entitlement

#### Get API Keys

1. In RevenueCat, go to your project → **API Keys**
2. Copy the **Public SDK Key** for iOS
3. You'll need to add this to your code (see below)

## Code Configuration

### Update RevenueCat API Key

1. Open `LocatedApp/LocatedApp/SubscriptionService.swift`
2. Find line 31:
   ```swift
   private let revenueCatAPIKey = "REPLACE_WITH_YOUR_REVENUECAT_API_KEY"
   ```
3. Replace with your actual RevenueCat Public SDK Key:
   ```swift
   private let revenueCatAPIKey = "appl_xxxxxxxxxxxxxxxxxxxxx"
   ```

### Update Product Identifier (if different)

If you used a different Product ID than `located_family_monthly`, you'll need to ensure the entitlement ID in RevenueCat is set to `premium` (which the code expects).

## Testing

### Sandbox Testing

1. Create a Sandbox Tester Account in App Store Connect:
   - Go to **Users and Access** → **Sandbox Testers**
   - Create a new tester with a unique email
   - **Important**: Use a different email than your Apple ID

2. On your iPhone:
   - Go to **Settings** → **App Store** → **Sandbox Account**
   - Sign in with your sandbox tester account

3. Build and run the app in Xcode
4. Create a family (this should start the 7-day trial)
5. Try to purchase the subscription
   - The App Store will show "[Sandbox]" to indicate it's a test purchase
   - You won't be charged real money
   - The subscription will renew much faster in sandbox (e.g., 5 minutes for a monthly subscription)

### Test Scenarios

1. **New User Trial**:
   - Create a new family
   - Verify trial status appears in subscription settings
   - Confirm 7 days remaining is shown

2. **Trial Expiration** (accelerated in sandbox):
   - Wait for trial to expire (or manually set expiry in RevenueCat dashboard)
   - App should show paywall to family creator
   - Other family members should see "Contact [creator] to renew" message

3. **Purchase Flow**:
   - Complete sandbox purchase
   - Verify subscription status changes to "Active"
   - Confirm access is restored

4. **Restore Purchases**:
   - Delete and reinstall app
   - Sign in with same user
   - Tap "Restore Purchases"
   - Verify subscription is restored

## RevenueCat Webhook (Optional but Recommended)

For cross-platform support (when you add Android), set up webhooks:

1. In RevenueCat, go to **Integrations** → **Webhooks**
2. Add webhook URL: `https://us-central1-located-d9dce.cloudfunctions.net/revenuecatWebhook`
3. Select events to send:
   - `INITIAL_PURCHASE`
   - `RENEWAL`
   - `CANCELLATION`
   - `EXPIRATION`

4. Update your Cloud Functions to handle webhook:
   ```javascript
   exports.revenuecatWebhook = functions.https.onRequest(async (req, res) => {
     // Handle RevenueCat webhook events
     // Update Firestore family subscription status
   });
   ```

## Production Checklist

Before submitting to the App Store:

- [ ] RevenueCat API key is updated in code
- [ ] Subscription product is approved in App Store Connect
- [ ] RevenueCat App Store Connect integration is configured
- [ ] Entitlement `premium` is created and linked to product
- [ ] Tested subscription flow in sandbox
- [ ] Tested trial expiration
- [ ] Tested restore purchases
- [ ] Terms of Service URL is updated in PaywallView.swift
- [ ] Privacy Policy URL is updated in PaywallView.swift
- [ ] Set RevenueCat log level to `.info` in production

## Pricing Recommendation

For a family location tracking app, consider these pricing tiers:

- **Monthly**: $4.99/month (most common for family apps)
- **Annual**: $39.99/year (20% discount, better retention)

Consider adding an annual plan later to increase LTV (Lifetime Value).

## Support

- RevenueCat Documentation: https://docs.revenuecat.com/
- Apple In-App Purchase Guide: https://developer.apple.com/in-app-purchase/
- RevenueCat Community: https://community.revenuecat.com/

## Troubleshooting

### "No products found"
- Verify Product ID matches exactly in App Store Connect and RevenueCat
- Ensure subscription is approved in App Store Connect
- Check that entitlement is properly linked in RevenueCat
- Wait a few hours after creating product (can take time to propagate)

### "Purchase failed"
- Verify sandbox tester account is signed in
- Check that Paid Applications agreement is completed
- Ensure banking/tax info is complete in App Store Connect

### "Can't connect to RevenueCat"
- Verify API key is correct
- Check internet connection
- Verify app bundle ID matches RevenueCat configuration

## Next Steps

After implementing subscriptions:

1. Monitor analytics in RevenueCat dashboard
2. Track conversion rates (trial → paid)
3. Analyze churn rate
4. Consider adding annual plan after 1-2 months
5. A/B test pricing (use RevenueCat Experiments)
6. Add Android app using same RevenueCat project


