/**
 * Firebase Cloud Functions for Located App
 * Handles geofence event notifications and push messaging
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
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

        // Get child's profile to find authorized parents
        const childDoc = await admin.firestore()
            .collection("users")
            .doc(childId)
            .get();

        if (!childDoc.exists) {
          logger.error(`Child document not found: ${childId}`);
          return;
        }

        const childData = childDoc.data();
        const parents = childData.parents || [];

        if (parents.length === 0) {
          logger.warn(`No parents found for child: ${childId}`);
          return;
        }

        // Get FCM tokens for all parents
        const parentTokens = [];
        const parentPromises = parents.map(async (parentId) => {
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
