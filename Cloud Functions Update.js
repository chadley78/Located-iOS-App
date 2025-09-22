const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { v4: uuidv4 } = require('uuid');

admin.initializeApp();
const db = admin.firestore();

// ... existing code for createInvitation and acceptInvitation ...

/**
 * Creates a new family document and sets the calling user as the first parent.
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
```

**2. Update the iOS Client Logic**

The app must be changed to call this new function instead of trying to write to Firestore directly.

**Example Swift Code:**

```swift
import FirebaseFunctions

// ... inside a view model or service class
lazy var functions = Functions.functions()

func createFamily(familyName: String, parentName: String) {
    functions.httpsCallable("createFamily").call(["familyName": familyName, "parentName": parentName]) { result, error in
        if let error = error as NSError? {
            print("Error calling createFamily function: \(error.localizedDescription)")
            // Handle error in the UI
            return
        }
        if let familyId = (result?.data as? [String: Any])?["familyId"] as? String {
            print("Family created successfully with ID: \(familyId)")
            // Now you have the familyId, you can save it to the user's local state
            // and proceed to the main parent view.
        }
    }
}
