const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nacl = require("tweetnacl");
nacl.util = require("tweetnacl-util");

admin.initializeApp();

exports.computeYTimesXPubPK = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }


  const uid = data.uid;
  const docRef =admin.firestore().collection("usersPreKeyValidations").doc(uid);
  const doc = await docRef.get();

  const y = nacl.randomBytes(32);
  console.log("y:", y);

  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Document not found");
  }

  const xPubPK = nacl.util.decodeBase64(doc.data()["X times PreKey Public"]);

  // Compute y * (x * PKa)
  const yTimesXPubPK = nacl.scalarMult(y, xPubPK);

  // Update Firestore with yTimesXPubPK
  await docRef.update({
    "Y times X times PreKey Public": nacl.util.encodeBase64(yTimesXPubPK),
    "Y": nacl.util.encodeBase64(y),
  });

  return {success: true, yxpub: nacl.util.encodeBase64(yTimesXPubPK)};
});

exports.verifyYTimesPubPK = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }

  const uid = data.uid;
  const docRef =admin.firestore().collection("usersPreKeyValidations").doc(uid);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Document not found");
  }

  const yPubPKBase64 = doc.data()["Y times PreKey Public"];
  const PubPKBase64 = doc.data()["PreKey Public"];
  const yBase64 = doc.data()["Y"];

  const yr = nacl.util.decodeBase64(yBase64);
  console.log("yPubPKBase64:", yPubPKBase64);


  const PubPK = nacl.util.decodeBase64(PubPKBase64);
  const yTimesPubPK = nacl.scalarMult(yr, PubPK);
  const yTimesPubPKBase64 = nacl.util.encodeBase64(yTimesPubPK);
  console.log("Computed yTimesPubPKBase64:", yTimesPubPKBase64);

  if (yPubPKBase64 === yTimesPubPKBase64) {
    await docRef.update({
      "PreKey Verification Status": "verified",
    });
  } else {
    await docRef.update({
      "PreKey Verification Status": "not verified",
    });
  }
  return {success: true};
});


exports.checkEmailExists = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }

  const email = data.email;

  try {
    // Query Firestore to check if the email exists
    const querySnapshot = await admin.firestore().collection("user's")
        .where("email", "==", email).get();

    if (!querySnapshot.empty) {
      return {success: true, exists: true};
    } else {
      return {success: true, exists: false};
    }
  } catch (error) {
    console.error("Error checking email:", error);
    throw new functions.https.HttpsError("internal",
        "Unable to check email existence");
  }
});
