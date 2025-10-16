# RevenueCat Dashboard Testing Guide

This guide explains how to test the subscription integration and see changes in the RevenueCat dashboard.

## 🎯 What You'll See in RevenueCat Dashboard

### RevenueCat Dashboard Location
1. Go to: https://app.revenuecat.com
2. Select your project
3. Go to **Customers** tab
4. Search for your user ID: `pW0y8pfkezfDikBlGYlIv9X7RGs2`

### What RevenueCat Tracks

#### ✅ **Automatically Tracked by RevenueCat:**
- **Active App Store subscriptions** (after purchase)
- **Purchase history**
- **Revenue data**
- **Subscription renewals/cancellations**
- **Refunds**

#### ✅ **Custom Attributes We're Syncing:**
- `subscription_status` - Current status (trial/active/expired)
- `trial_ends_at` - When Firestore trial expires
- `trial_days_remaining` - Days left in trial
- `family_name` - Name of the family
- `family_id` - Firestore family ID
- `is_family_creator` - Whether this user created the family

## 🧪 Testing Each Subscription State

### 1. **Active Trial (Initial State)**

**Setup:**
```
Firestore families/{familyId}:
  subscriptionStatus: "trial"
  trialEndsAt: [7 days from now]
  subscriptionExpiresAt: [7 days from now]
```

**In RevenueCat Dashboard:**
- User shows up with ID `pW0y8pfkezfDikBlGYlIv9X7RGs2`
- **Attributes** section shows:
  - `subscription_status`: "trial"
  - `trial_days_remaining`: "7"
  - `trial_ends_at`: "2025-10-23T..."
  - `family_name`: "The Flood Family"
  - `is_family_creator`: "true"
- **Entitlements**: None (no App Store purchase yet)
- **Active Subscriptions**: None

**In App:**
- ✅ Full access
- ✅ Settings shows "Free Trial | 7 days left"
- ✅ No paywall

---

### 2. **Expired Trial**

**Setup (in Firebase Console):**
```
Firestore families/{familyId}:
  subscriptionStatus: "expired"
  trialEndsAt: [past date, e.g., 2025-10-10]
  subscriptionExpiresAt: [past date]
```

**In RevenueCat Dashboard:**
- **Attributes** section shows:
  - `subscription_status`: "expired"
  - `trial_days_remaining`: "0"
  - `trial_ends_at`: "2025-10-10T..."
  - `is_family_creator`: "true"
- **Entitlements**: None
- **Active Subscriptions**: None

**In App:**
- ✅ Full-screen paywall blocks access
- ✅ "Trial Expired" message
- ✅ "Upgrade to Continue" button
- ✅ Settings shows "Expired"

---

### 3. **Active Subscription (After Purchase)**

**Setup:**
- Complete a test purchase using a sandbox account
- Or use RevenueCat's "Grant Promotional Entitlement" feature

**In RevenueCat Dashboard:**
- **Entitlements**: Shows "premium" entitlement as active
- **Active Subscriptions**: Shows subscription details
  - Product: `located_family_monthly`
  - Start date
  - Renewal date
  - Revenue
- **Attributes** still show (now redundant):
  - `subscription_status`: "active"

**In App:**
- ✅ No paywall
- ✅ Full access
- ✅ Settings shows "Active | Renews [date]"

---

### 4. **Canceled (But Active Until End)**

**Setup:**
- Purchase subscription
- Cancel in App Store (but still active until period ends)

**In RevenueCat Dashboard:**
- **Entitlements**: Still shows "premium" as active
- **Active Subscriptions**: Shows "Will not renew"
- **Attributes**: `subscription_status`: "canceled"

**In App:**
- ✅ Full access (until expiration)
- ✅ Settings shows "Expires at end of period"

---

## 📊 How to View in RevenueCat Dashboard

1. **Login**: https://app.revenuecat.com
2. **Navigate**: Customers → Search for user ID
3. **View Details**:
   - Click on customer name
   - See **Overview** tab for subscriptions
   - See **Attributes** tab for custom data
   - See **Purchase History** for all transactions

## 🔄 When Attributes Update

Attributes are synced to RevenueCat when:
- ✅ User logs in (identifies with RevenueCat)
- ✅ App launches and user is authenticated
- ✅ Subscription status changes in Firestore

**Note:** Attributes may take a few seconds to appear in dashboard. Refresh the customer page if needed.

## 🧪 Testing Workflow

### Test Sequence:
1. **Start**: Active trial → Check dashboard shows trial attributes
2. **Expire**: Set trial to past → Check dashboard shows expired
3. **Purchase**: Use sandbox account → Check dashboard shows active subscription
4. **Cancel**: Cancel subscription → Check dashboard shows canceled but active

### What to Verify:
- [ ] User appears in RevenueCat Customers list
- [ ] Attributes show current trial status
- [ ] Attributes update when Firestore changes
- [ ] Purchase creates entitlement
- [ ] Revenue tracking works (for paid subscriptions)

## 💡 Tips

- **Refresh Required**: Dashboard doesn't auto-update, click refresh icon
- **Search**: Use email or user ID to find customer
- **Sandbox vs Production**: Sandbox purchases show differently
- **Attributes Limit**: RevenueCat allows many custom attributes for segmentation

## 🔗 RevenueCat Dashboard Links

- **Customers**: https://app.revenuecat.com/customers
- **Overview**: Dashboard → Overview (see revenue, active subs)
- **Products**: Dashboard → Products (see product configuration)
- **Offerings**: Dashboard → Offerings (see what users can purchase)

---

**Now test it!** After each state change:
1. Make change in Firebase Console
2. Restart app
3. Check RevenueCat dashboard (search for your user)
4. Verify attributes updated

