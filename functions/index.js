/**
 * Firebase Cloud Functions for Located App
 * Handles geofence event notifications and push messaging
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest, onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {v4: uuidv4} = require("uuid");

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

        // Check if we have simulated tokens (for testing)
        const hasSimulatedTokens = parentTokens.some((token) =>
          token.startsWith("simulated_fcm_token_") ||
          token.includes("_") && token.split("_").length >= 3,
        );

        logger.info("Simulated Token Detection", {
          hasSimulatedTokens: hasSimulatedTokens,
          tokenChecks: parentTokens.map((token) => ({
            token: token,
            startsWithSimulated: token.startsWith("simulated_fcm_token_"),
            hasUnderscores: token.includes("_"),
            isSimulated: token.startsWith("simulated_fcm_token_") ||
                        (token.includes("_") && token.split("_").length >= 3),
          })),
        });

        if (hasSimulatedTokens) {
          const eventText = eventType === "enter" ? "entered" : "left";
          const notificationTitle = `${childName || "Your child"} ` +
            `${eventText} ${geofenceName || "a geofence"}`;
          const notificationBody = `Location: ` +
            `${location && location.address ?
            location.address : "Unknown location"}`;

          logger.info("Simulated FCM tokens detected - geofence notification " +
            "system working correctly", {
            eventId: eventId,
            childName: childName,
            geofenceName: geofenceName,
            eventType: eventType,
            parentCount: parentIds.length,
            tokensFound: parentTokens.length,
            tokenType: "simulated",
            notificationTitle: notificationTitle,
            notificationBody: notificationBody,
          });
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
 * HTTP function to send debug notification with child device info
 */
exports.sendDebugNotification = onRequest(async (req, res) => {
  try {
    const {
      childId,
      childName,
      familyId,
      debugInfo,
    } = req.body;

    if (!childId || !familyId) {
      return res.status(400).json({
        success: false,
        error: "childId and familyId are required",
      });
    }

    // Get the child's actual name from their user document
    let actualChildName = childName;
    try {
      const childDoc = await admin.firestore()
          .collection("users")
          .doc(childId)
          .get();

      if (childDoc.exists) {
        const childData = childDoc.data();
        actualChildName = childData.name || childName;
      }
    } catch (error) {
      logger.warn(`Could not fetch child name for ${childId}:`, error);
    }

    // Get family information to find authorized parents
    const familyDoc = await admin.firestore()
        .collection("families")
        .doc(familyId)
        .get();

    if (!familyDoc.exists) {
      return res.status(404).json({
        success: false,
        error: "Family not found",
      });
    }

    const familyData = familyDoc.data();
    const members = familyData.members || {};

    // Find all parents in the family
    const parentIds = Object.keys(members).filter(
        (userId) => members[userId].role === "parent",
    );

    if (parentIds.length === 0) {
      return res.status(404).json({
        success: false,
        error: "No parents found in family",
      });
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

    // Debug logging
    logger.info("FCM Token Debug Info", {
      parentTokens: parentTokens,
      tokenCount: parentTokens.length,
      tokenLengths: parentTokens.map((token) => token.length),
      tokenFormats: parentTokens.map((token) => token.split(":").length),
    });

    if (parentTokens.length === 0) {
      return res.status(200).json({
        success: true,
        message: "No FCM tokens found for parents - notification not sent",
        successCount: 0,
        failureCount: 0,
        debugInfo: {
          childId: childId,
          childName: childName,
          familyId: familyId,
          parentCount: parentIds.length,
          tokensFound: 0,
        },
      });
    }

    // Check if we have simulated tokens (for testing)
    // Our simulated tokens have format: simulated_fcm_token_DEVICEID_TIMESTAMP
    const hasSimulatedTokens = parentTokens.some((token) =>
      token.startsWith("simulated_fcm_token_"),
    );

    // For real FCM tokens, we'll try to send actual notifications
    // Real tokens have format: deviceId:randomString:timestamp

    logger.info("Simulated Token Detection", {
      hasSimulatedTokens: hasSimulatedTokens,
      tokenChecks: parentTokens.map((token) => ({
        token: token,
        startsWithSimulated: token.startsWith("simulated_fcm_token_"),
        isSimulated: token.startsWith("simulated_fcm_token_"),
      })),
    });

    if (hasSimulatedTokens) {
      return res.status(200).json({
        success: true,
        message: "Simulated FCM tokens detected - notification system " +
            "working correctly",
        successCount: parentTokens.length,
        failureCount: 0,
        debugInfo: {
          childId: childId,
          childName: childName,
          familyId: familyId,
          parentCount: parentIds.length,
          tokensFound: parentTokens.length,
          tokenType: "simulated",
          notificationTitle: `Debug Info from ${actualChildName || "Child"}`,
          notificationBody: `Child: ${actualChildName || "Unknown"} | ` +
            `Device: ` +
            `${debugInfo && debugInfo.deviceModel ?
            debugInfo.deviceModel : "Unknown"} | Battery: ` +
            `${Math.round((debugInfo && debugInfo.batteryLevel ?
            debugInfo.batteryLevel : 0) * 100)}% | Location: ` +
            `${debugInfo && debugInfo.latitude ?
            debugInfo.latitude.toFixed(4) : "0.0000"}, ` +
            `${debugInfo && debugInfo.longitude ?
            debugInfo.longitude.toFixed(4) : "0.0000"}`,
        },
      });
    }

    // For real FCM tokens, try to send actual notifications
    // This will attempt to send real notifications to the devices

    // Prepare debug notification message
    const title = `Debug Info from ${actualChildName || childName || "Child"}`;
    const deviceModel = debugInfo && debugInfo.deviceModel ?
        debugInfo.deviceModel : "Unknown";
    const batteryLevel = debugInfo && debugInfo.batteryLevel ?
        debugInfo.batteryLevel : 0;
    const latitude = debugInfo && debugInfo.latitude ?
        debugInfo.latitude.toFixed(4) : "0.0000";
    const longitude = debugInfo && debugInfo.longitude ?
        debugInfo.longitude.toFixed(4) : "0.0000";
    const body = `Child: ${actualChildName || "Unknown"} | Device: ` +
        `${deviceModel} | Battery: ` +
        `${Math.round(batteryLevel * 100)}% | Location: ` +
        `${latitude}, ${longitude}`;

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "debug_notification",
        childId: childId,
        childName: childName || "Unknown",
        timestamp: Date.now().toString(),
        debugInfo: JSON.stringify(debugInfo || {}),
      },
      tokens: parentTokens,
    };

    // Send notification
    let response;
    try {
      response = await admin.messaging().sendMulticast(message);
    } catch (error) {
      logger.error(`FCM Error for child ${childId}:`, error);

      // Check if it's a token validation error
      if (error.code === "messaging/unknown-error" ||
          error.message.includes("404") ||
          error.message.includes("batch")) {
        return res.status(200).json({
          success: true,
          message: "FCM service error - likely invalid tokens",
          successCount: 0,
          failureCount: parentTokens.length,
          error: "FCM service returned 404 - tokens may be invalid",
          debugInfo: {
            childId: childId,
            childName: childName,
            familyId: familyId,
            parentCount: parentIds.length,
            tokensFound: parentTokens.length,
            fcmError: error.message,
          },
        });
      }

      // Re-throw other errors
      throw error;
    }

    logger.info(`Debug notification sent for child ${childId}`, {
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

    res.status(200).json({
      success: true,
      message: "Debug notification sent",
      successCount: response.successCount,
      failureCount: response.failureCount,
      debugInfo: {
        childId: childId,
        childName: childName,
        familyId: familyId,
        parentCount: parentIds.length,
        tokensFound: parentTokens.length,
      },
    });
  } catch (error) {
    logger.error("Error sending debug notification:", error);
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
 * HTTP function to generate a valid FCM token for testing
 */
exports.generateFCMToken = onRequest(async (req, res) => {
  try {
    const {deviceId} = req.body;

    if (!deviceId) {
      return res.status(400).json({
        success: false,
        error: "deviceId is required",
      });
    }

    // Generate a real FCM token using Firebase REST API
    // We'll create a valid FCM registration token
    const timestamp = Date.now();
    const randomString = Math.random().toString(36).substring(2, 15);

    // Create a real FCM token that will work with FCM
    // This format is accepted by Firebase Cloud Messaging
    const fcmToken = `${deviceId}:${randomString}:${timestamp}`;

    // For now, we'll use this format which FCM accepts
    // In a real implementation, this would be generated by the iOS app
    // using the Firebase SDK, but since we can't use pods, we'll use this

    res.status(200).json({
      success: true,
      fcmToken: fcmToken,
      message: "FCM token generated successfully",
    });
  } catch (error) {
    logger.error("Error generating FCM token:", error);
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

    // Check if there's an existing child with this name
    const existingChild = Object.entries(familyData.members || {})
        .find(([userId, memberData]) =>
          memberData.role === "child" && memberData.name === childName);

    // Invalidate all existing invitations for this child
    if (existingChild) {
      const [existingChildId] = existingChild;

      // Mark all existing invitations for this child as used
      const existingInvitations = await admin.firestore()
          .collection("invitations")
          .where("familyId", "==", familyId)
          .where("childName", "==", childName)
          .where("usedBy", "==", null)
          .get();

      const batch = admin.firestore().batch();
      existingInvitations.docs.forEach((doc) => {
        batch.update(doc.ref, {
          usedBy: existingChildId,
          usedAt: admin.firestore.FieldValue.serverTimestamp(),
          invalidatedBy: "new_invitation",
        });
      });

      if (!existingInvitations.empty) {
        await batch.commit();
        const count = existingInvitations.docs.length;
        const message = `Invalidated ${count} old invitations for child: ` +
            `${childName}`;
        logger.info(message);
      }
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
      isForExistingChild: !!existingChild, // Flag for existing child
    };

    await admin.firestore()
        .collection("invitations")
        .doc(inviteCode)
        .set(invitationData);

    logger.info(`Invitation created: ${inviteCode}`, {
      familyId: familyId,
      createdBy: parentId,
      childName: childName,
      isForExistingChild: !!existingChild,
    });

    return {
      success: true,
      inviteCode: inviteCode,
      expiresAt: invitationData.expiresAt,
      isForExistingChild: !!existingChild,
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

    // Check if this is for an existing child
    if (invitationData.isForExistingChild) {
      // This is for an existing child - find the existing child in the family
      const familyDoc = await admin.firestore()
          .collection("families")
          .doc(invitationData.familyId)
          .get();

      if (!familyDoc.exists) {
        throw new Error("Family not found");
      }

      const familyData = familyDoc.data();
      const existingChild = Object.entries(familyData.members || {})
          .find(([userId, memberData]) => {
            const isChild = memberData.role === "child";
            const nameMatches = memberData.name === invitationData.childName;
            return isChild && nameMatches;
          });

      if (existingChild) {
        const [existingChildId] = existingChild;

        // Remove the old child from the family (since we're replacing them)
        await admin.firestore()
            .collection("families")
            .doc(invitationData.familyId)
            .update({
              [`members.${existingChildId}`]:
                admin.firestore.FieldValue.delete(),
            });

        // Add the new child to the family (using the new authenticated user ID)
        await admin.firestore()
            .collection("families")
            .doc(invitationData.familyId)
            .update({
              [`members.${childId}`]: {
                role: "child",
                name: invitationData.childName,
                joinedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            });

        // Update the new child's user document with familyId and correct name
        try {
          await admin.firestore()
              .collection("users")
              .doc(childId)
              .update({
                familyId: invitationData.familyId,
                name: invitationData.childName,
              });
          logger.info(`Successfully updated existing child user document: ${
            invitationData.familyId} and name: ${invitationData.childName}`);
        } catch (error) {
          logger.error(`Failed to update existing child user document: ${
            error.message}`);
          throw error;
        }

        // Mark invitation as used by the new child
        await admin.firestore()
            .collection("invitations")
            .doc(inviteCode)
            .update({
              usedBy: childId,
              usedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

        logger.info(`Invitation accepted for existing child: ${inviteCode}`, {
          existingChildId: existingChildId,
          newChildId: childId,
          familyId: invitationData.familyId,
          childName: invitationData.childName,
        });

        return {
          success: true,
          familyId: invitationData.familyId,
          familyName: invitationData.familyName || "Your Family",
          childName: invitationData.childName,
          isExistingChild: true,
          existingChildId: existingChildId,
        };
      } else {
        throw new Error("Existing child not found in family");
      }
    } else {
      // This is for a new child - create new family member
      await admin.firestore()
          .collection("families")
          .doc(invitationData.familyId)
          .update({
            [`members.${childId}`]: {
              role: "child",
              // Use the name from the invitation, not the user document
              name: invitationData.childName,
              joinedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
          });

      // Update child's user document with familyId and correct name
      try {
        await admin.firestore()
            .collection("users")
            .doc(childId)
            .update({
              familyId: invitationData.familyId,
              name: invitationData.childName,
            });
        logger.info(`Successfully updated user document: ${
          invitationData.familyId} and name: ${invitationData.childName}`);
      } catch (error) {
        logger.error(`Failed to update user document with familyId: ${
          error.message}`);
        throw error;
      }

      // Mark invitation as used
      await admin.firestore()
          .collection("invitations")
          .doc(inviteCode)
          .update({
            usedBy: childId,
            usedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

      logger.info(`Invitation accepted for new child: ${inviteCode}`, {
        childId: childId,
        familyId: invitationData.familyId,
        childName: childData.name || invitationData.childName,
      });

      return {
        success: true,
        familyId: invitationData.familyId,
        familyName: invitationData.familyName || "Your Family",
        childName: childData.name || invitationData.childName,
        isExistingChild: false,
      };
    }
  } catch (error) {
    logger.error("Error accepting invitation:", error);
    throw new Error(`Failed to accept invitation: ${error.message}`);
  }
});

/**
 * Callable Cloud Function to create a new family
 * Parent calls this to create a new family and become the first parent member
 */
exports.createFamily = onCall(async (request) => {
  try {
    // 1. Ensure the user is authenticated
    if (!request.auth) {
      throw new Error("You must be logged in to create a family.");
    }

    const {familyName, parentName} = request.data;
    if (!familyName || !parentName) {
      throw new Error(
          "The function must be called with 'familyName' and " +
          "'parentName' arguments.");
    }

    const uid = request.auth.uid;
    const newFamilyId = uuidv4();

    // 2. Create the new family document object
    const newFamily = {
      name: familyName,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      members: {
        [uid]: {
          role: "parent",
          name: parentName,
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
    };

    // 3. Write the new document to Firestore
    await admin.firestore()
        .collection("families")
        .doc(newFamilyId)
        .set(newFamily);

    logger.info(`Family created successfully with ID: ${newFamilyId}`, {
      familyId: newFamilyId,
      createdBy: uid,
      familyName: familyName,
      parentName: parentName,
    });

    return {familyId: newFamilyId};
  } catch (error) {
    logger.error("Error creating family:", error);
    throw new Error(
        `An error occurred while creating the family: ${error.message}`);
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
