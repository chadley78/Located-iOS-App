/**
 * Firebase Cloud Functions for Located App
 * Handles geofence event notifications and push messaging
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Set global options for cost control
setGlobalOptions({maxInstances: 10});

/**
 * Cloud Function triggered when a geofence event is created
 * Sends push notifications to authorized parents
 */
exports.onGeofenceEvent = onDocumentCreated(
    "geofence_events/{eventId}",
    async (event) => {
      try {
        const eventData = event.data.data();
        const eventId = event.params.eventId;

        logger.info(`Processing geofence event: ${eventId}`, {
          eventData: eventData,
          structuredData: true,
        });

        // Extract event details
        const {
          childId,
          childName,
          geofenceId,
          geofenceName,
          eventType, // 'enter' or 'exit'
          timestamp,
          location,
        } = eventData;

        if (!childId || !eventType) {
          logger.error("Missing required fields in geofence event", {
            eventId: eventId,
            eventData: eventData,
          });
          return;
        }

        // Get family information to find authorized parents
        const familyId = eventData.familyId;
        if (!familyId) {
          logger.error(`No familyId found in geofence event: ${eventId}`);
          return;
        }

        const familyDoc = await admin.firestore()
            .collection("families")
            .doc(familyId)
            .get();

        if (!familyDoc.exists) {
          logger.error(`Family document not found: ${familyId}`);
          return;
        }

        const familyData = familyDoc.data();
        const members = familyData.members || {};

        // Find all parents in the family
        const parentIds = Object.keys(members).filter(
            (userId) => members[userId].role === "parent",
        );

        if (parentIds.length === 0) {
          logger.warn(`No parents found in family: ${familyId}`);
          return;
        }

        // Get FCM tokens for all parents
        const parentTokens = [];
        const parentPromises = parentIds.map(async (parentId) => {
          try {
            const parentDoc = await admin.firestore()
                .collection("users")
                .doc(parentId)
                .get();

            if (parentDoc.exists) {
              const parentData = parentDoc.data();
              const fcmTokens = parentData.fcmTokens || [];
              return fcmTokens;
            }
            return [];
          } catch (error) {
            logger.error(`Error fetching parent ${parentId}:`, error);
            return [];
          }
        });

        const allTokens = await Promise.all(parentPromises);
        parentTokens.push(...allTokens.flat());

        if (parentTokens.length === 0) {
          logger.warn(`No FCM tokens found for parents of child: ${childId}`);
          return;
        }

        // Prepare notification message
        const eventText = eventType === "enter" ? "entered" : "left";
        const title = `${childName || "Your child"} ${eventText} ` +
            `${geofenceName || "a geofence"}`;
        const body = `Location: ${location && location.address ?
            location.address : "Unknown location"}`;

        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: "geofence_event",
            childId: childId,
            childName: childName || "Unknown",
            geofenceId: geofenceId || "",
            geofenceName: geofenceName || "Unknown",
            eventType: eventType,
            timestamp: timestamp ? timestamp.toString() : Date.now().toString(),
            location: JSON.stringify(location || {}),
          },
          tokens: parentTokens,
        };

        // Send notification
        const response = await admin.messaging().sendMulticast(message);

        logger.info(`Notification sent for geofence event ${eventId}`, {
          successCount: response.successCount,
          failureCount: response.failureCount,
          responses: response.responses,
        });

        // Handle failed tokens (remove invalid ones)
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(parentTokens[idx]);
            logger.warn(`Failed to send to token ${idx}:`, resp.error);
          }
        });

        // Remove failed tokens from user documents
        if (failedTokens.length > 0) {
          await cleanupFailedTokens(failedTokens);
        }
      } catch (error) {
        logger.error("Error processing geofence event:", error);
      }
    },
);

/**
 * Helper function to clean up failed FCM tokens
 * @param {string[]} failedTokens Array of failed FCM tokens to remove
 */
async function cleanupFailedTokens(failedTokens) {
  try {
    // Get all users and remove failed tokens
    const usersSnapshot = await admin.firestore()
        .collection("users")
        .get();

    const batch = admin.firestore().batch();
    let batchCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmTokens = userData.fcmTokens || [];

      // Filter out failed tokens
      const validTokens = fcmTokens.filter((token) =>
        !failedTokens.includes(token),
      );

      if (validTokens.length !== fcmTokens.length) {
        batch.update(userDoc.ref, {fcmTokens: validTokens});
        batchCount++;

        if (batchCount >= 500) { // Firestore batch limit
          await batch.commit();
          batchCount = 0;
        }
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    logger.info(`Cleaned up ${failedTokens.length} failed FCM tokens`);
  } catch (error) {
    logger.error("Error cleaning up failed tokens:", error);
  }
}

/**
 * HTTP function to test the geofence notification system
 */
exports.testGeofenceNotification = onRequest(async (req, res) => {
  try {
    // This is a test endpoint - in production, you'd want to secure this
    const testEvent = {
      childId: req.body.childId || "test-child-id",
      childName: req.body.childName || "Test Child",
      geofenceId: req.body.geofenceId || "test-geofence-id",
      geofenceName: req.body.geofenceName || "Test Geofence",
      eventType: req.body.eventType || "enter",
      timestamp: Date.now(),
      location: {
        lat: req.body.lat || 37.7749,
        lng: req.body.lng || -122.4194,
        address: req.body.address || "Test Location",
      },
    };

    // Manually trigger the geofence event processing
    await admin.firestore()
        .collection("geofence_events")
        .add(testEvent);

    res.status(200).json({
      success: true,
      message: "Test geofence event created",
      event: testEvent,
    });
  } catch (error) {
    logger.error("Error in test function:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * HTTP function to register FCM tokens for users
 */
exports.registerFCMToken = onRequest(async (req, res) => {
  try {
    const {userId, fcmToken} = req.body;

    if (!userId || !fcmToken) {
      return res.status(400).json({
        success: false,
        error: "userId and fcmToken are required",
      });
    }

    // Add token to user's FCM tokens array
    await admin.firestore()
        .collection("users")
        .doc(userId)
        .update({
          fcmTokens: admin.firestore.FieldValue.arrayUnion(fcmToken),
        });

    res.status(200).json({
      success: true,
      message: "FCM token registered successfully",
    });
  } catch (error) {
    logger.error("Error registering FCM token:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

/**
 * Callable Cloud Function to create a family invitation
 * Parent calls this to generate an invite code for their child
 */
exports.createInvitation = onCall(async (request) => {
  try {
    const {familyId, childName} = request.data;
    const parentId = request.auth.uid;

    if (!familyId || !childName) {
      throw new Error("familyId and childName are required");
    }

    // Verify the user is a parent in this family
    const familyDoc = await admin.firestore()
        .collection("families")
        .doc(familyId)
        .get();

    if (!familyDoc.exists) {
      throw new Error("Family not found");
    }

    const familyData = familyDoc.data();
    const memberData = familyData.members[parentId];

    if (!memberData || memberData.role !== "parent") {
      throw new Error("Only parents can create invitations");
    }

    // Generate a unique 6-character alphanumeric invite code
    const inviteCode = generateInviteCode();

    // Create invitation document
    const invitationData = {
      familyId: familyId,
      createdBy: parentId,
      childName: childName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
      usedBy: null,
    };

    await admin.firestore()
        .collection("invitations")
        .doc(inviteCode)
        .set(invitationData);

    logger.info(`Invitation created: ${inviteCode}`, {
      familyId: familyId,
      createdBy: parentId,
      childName: childName,
    });

    return {
      success: true,
      inviteCode: inviteCode,
      expiresAt: invitationData.expiresAt,
    };
  } catch (error) {
    logger.error("Error creating invitation:", error);
    throw new Error(`Failed to create invitation: ${error.message}`);
  }
});

/**
 * Callable Cloud Function to accept a family invitation
 * Child calls this to join a family using an invite code
 */
exports.acceptInvitation = onCall(async (request) => {
  try {
    const {inviteCode} = request.data;
    const childId = request.auth.uid;

    if (!inviteCode) {
      throw new Error("inviteCode is required");
    }

    // Get invitation document
    const invitationDoc = await admin.firestore()
        .collection("invitations")
        .doc(inviteCode)
        .get();

    if (!invitationDoc.exists) {
      throw new Error("Invalid invitation code");
    }

    const invitationData = invitationDoc.data();

    // Check if invitation has expired
    const now = new Date();
    const expiresAt = invitationData.expiresAt.toDate();
    if (now > expiresAt) {
      throw new Error("Invitation has expired");
    }

    // Check if invitation has already been used
    if (invitationData.usedBy) {
      throw new Error("Invitation has already been used");
    }

    // Get child's user data
    const childDoc = await admin.firestore()
        .collection("users")
        .doc(childId)
        .get();

    if (!childDoc.exists) {
      throw new Error("Child user not found");
    }

    const childData = childDoc.data();

    // Add child to family
    await admin.firestore()
        .collection("families")
        .doc(invitationData.familyId)
        .update({
          [`members.${childId}`]: {
            role: "child",
            name: childData.name || invitationData.childName,
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        });

    // Mark invitation as used
    await admin.firestore()
        .collection("invitations")
        .doc(inviteCode)
        .update({
          usedBy: childId,
          usedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    logger.info(`Invitation accepted: ${inviteCode}`, {
      childId: childId,
      familyId: invitationData.familyId,
      childName: childData.name,
    });

    return {
      success: true,
      familyId: invitationData.familyId,
      familyName: invitationData.familyName || "Your Family",
    };
  } catch (error) {
    logger.error("Error accepting invitation:", error);
    throw new Error(`Failed to accept invitation: ${error.message}`);
  }
});

/**
 * Helper function to generate a unique 6-character alphanumeric invite code
 * @return {string} A unique invite code
 */
function generateInviteCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";

  // Generate 6-character code
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }

  return result;
}
