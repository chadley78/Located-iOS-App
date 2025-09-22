const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { v4: uuidv4 } = require('uuid');

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

/*
 * =================================================================
 * NEW FUNCTION TO BE ADDED (Task BE-04)
 * This is the new createFamily function, written in the correct
 * v1 Cloud Functions syntax.
 * =================================================================
 */
/**
 * Creates a new family document and sets the calling user as the first parent.
 * This is a Callable Function.
 *
 * @param {object} data - The data passed to the function.
 * @param {string} data.familyName - The desired name for the family.
 * @param {string} data.parentName - The name of the parent creating the family.
 *
 * @returns {object} - An object containing the new familyId.
 */
exports.createFamily = functions.https.onCall(async (data, context) => {
  // 1. Ensure the user is authenticated.
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in to create a family."
    );
  }

  const { familyName, parentName } = data;
  if (!familyName || !parentName) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with 'familyName' and 'parentName' arguments."
    );
  }

  const uid = context.auth.uid;
  const newFamilyId = uuidv4();

  // 2. Create the new family document object.
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

  // 3. Write the new document to Firestore.
  try {
    await db.collection("families").doc(newFamilyId).set(newFamily);
    console.log(`Family created successfully with ID: ${newFamilyId}`);
    return { familyId: newFamilyId };
  } catch (error) {
    console.error("Error creating family:", error);
    throw new functions.https.HttpsError(
      "internal",
      "An error occurred while creating the family."
    );
  }
});


/*
 * =================================================================
 * PLACEHOLDERS FOR EXISTING FUNCTIONS
 * Add your existing createInvitation and acceptInvitation functions here
 * if they are not already present.
 * =================================================================
 */

