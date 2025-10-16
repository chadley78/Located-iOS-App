# Testing Subscription Flow

This guide explains how to test the subscription and trial expiration UX.

## Quick Testing Guide

### Method 1: Firebase Console (Easiest)

1. Open Firebase Console: https://console.firebase.google.com/project/located-ba5bb/firestore/data
2. Navigate to: `families` → `1c0e25f1-88c8-4030-a601-afa377978d92`
3. Click **Edit** (pencil icon)
4. Update fields:
   - `trialEndsAt`: Set to past date (e.g., October 10, 2025)
   - `subscriptionExpiresAt`: Set to same past date
   - `subscriptionStatus`: Change to `"expired"`
5. Click **Update**
6. **Kill and restart your app** to see changes

### Method 2: Using Script (Requires firebase-admin)

**Note:** This requires `firebase-admin` npm package. Only use if you have Node.js setup.

```bash
# To expire the trial (test paywall)
node fix_family_subscription.js expire

# To reset trial (7 days)
node fix_family_subscription.js reset
```

## What to Test

### 1. Active Trial (Default)
- ✅ App works normally
- ✅ Settings shows "Free Trial | X days left"
- ✅ No paywall blocking access

### 2. Expired Trial
**After setting trial to past date:**

#### For Family Creator:
- ✅ App shows **paywall overlay** blocking all content
- ✅ Paywall displays:
  - "Trial Expired" title
  - Lock icon
  - "Upgrade to Continue" button
  - Subscription plans (when configured)
- ✅ Cannot dismiss paywall
- ✅ Settings shows "Expired" status

#### For Other Parents:
- ✅ App shows **paywall overlay**
- ✅ Paywall displays:
  - "Subscription Required" title
  - Info icon
  - "Contact [Creator Name] to renew" message
  - No purchase buttons
- ✅ Cannot dismiss paywall

### 3. Active Subscription
**After purchasing (sandbox testing):**
- ✅ Paywall removed
- ✅ Full access to all features
- ✅ Settings shows "Active" status
- ✅ Shows renewal date

## Testing Checklist

- [ ] Active trial shows correct days remaining
- [ ] Trial expiration triggers paywall
- [ ] Family creator sees purchase options
- [ ] Other parents see "contact creator" message
- [ ] Paywall blocks all app content when expired
- [ ] Settings screen shows correct status
- [ ] Only family creator can tap subscription card
- [ ] Non-creators see "Managed by family creator"

## Resetting for Clean Testing

To reset everything:

1. Use Firebase Console or script to set trial to 7 days from now
2. Set `subscriptionStatus` to `"trial"`
3. Restart the app

## Notes

- Changes in Firestore are detected in **real-time** but app restart ensures clean state
- Trial dates are stored in Firestore, not RevenueCat (until actual purchase)
- RevenueCat only manages actual paid subscriptions
- Sandbox purchases require App Store Connect configuration

