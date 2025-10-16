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
  
  try {
    // Calculate new trial end date (7 days from now)
    const trialEndsAt = new Date();
    trialEndsAt.setDate(trialEndsAt.getDate() + 7);
    
    // Update family document
    await db.collection('families').doc(familyId).update({
      subscriptionStatus: 'trial',
      trialEndsAt: trialEndsAt,
      subscriptionExpiresAt: trialEndsAt
    });
    
    console.log('✅ Family subscription status fixed!');
    console.log('   Status: trial');
    console.log('   Trial ends:', trialEndsAt.toISOString());
    console.log('   Expires:', trialEndsAt.toISOString());
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error fixing family subscription:', error);
    process.exit(1);
  }
}

fixFamilySubscription();

