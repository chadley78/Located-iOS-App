// Quick script to fix family subscription status
// Run: node fix_family_subscription.js

const admin = require('firebase-admin');

// Initialize Firebase Admin (uses default credentials)
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: 'https://located-ba5bb.firebaseio.com'
});

const db = admin.firestore();

async function fixFamilySubscription() {
  const familyId = '1c0e25f1-88c8-4030-a601-afa377978d92';
  
  // Get command line argument: 'expire' or 'reset' (default: reset)
  const mode = process.argv[2] || 'reset';
  
  try {
    let trialEndsAt;
    let subscriptionStatus;
    
    if (mode === 'expire') {
      // Set trial to expired (past date)
      trialEndsAt = new Date('2025-10-10T00:00:00Z'); // Past date
      subscriptionStatus = 'expired';
      
      console.log('🔴 Expiring trial for testing...');
    } else {
      // Reset to 7 days from now
      trialEndsAt = new Date();
      trialEndsAt.setDate(trialEndsAt.getDate() + 7);
      subscriptionStatus = 'trial';
      
      console.log('🟢 Resetting trial to 7 days...');
    }
    
    // Update family document
    await db.collection('families').doc(familyId).update({
      subscriptionStatus: subscriptionStatus,
      trialEndsAt: trialEndsAt,
      subscriptionExpiresAt: trialEndsAt
    });
    
    console.log('✅ Family subscription status updated!');
    console.log('   Status:', subscriptionStatus);
    console.log('   Trial ends:', trialEndsAt.toISOString());
    console.log('   Expires:', trialEndsAt.toISOString());
    console.log('\n💡 Restart your app to see changes!');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error updating family subscription:', error);
    process.exit(1);
  }
}

fixFamilySubscription();

