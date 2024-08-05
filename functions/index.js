const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nacl = require("tweetnacl");
nacl.util = require("tweetnacl-util");

admin.initializeApp();

const y = nacl.randomBytes(32);


exports.computeYTimesXPubPK = functions.https.onCall(async (data, context) => {
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

  const xPubPK = nacl.util.decodeBase64(doc.data()["X times PreKey Public"]);

  // Compute y * (x * PKa)
  const yTimesXPubPK = nacl.scalarMult(y, xPubPK);

  // Update Firestore with yTimesXPubPK
  await docRef.update({
    "Y times X times PreKey Public": nacl.util.encodeBase64(yTimesXPubPK),
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

  const PubPK = nacl.util.decodeBase64(PubPKBase64);
  const yTimesPubPK = nacl.scalarMult(y, PubPK);
  const yTimesPubPKBase64 = nacl.util.encodeBase64(yTimesPubPK);


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
