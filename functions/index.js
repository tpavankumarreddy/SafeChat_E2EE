///**
// * Import function triggers from their respective submodules:
// *
// * const {onCall} = require("firebase-functions/v2/https");
// * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
// *
// * See a full list of supported triggers at https://firebase.google.com/docs/functions
// */
//
//const {onRequest} = require("firebase-functions/v2/https");
//const logger = require("firebase-functions/logger");
//
//// Create and deploy your first functions
//// https://firebase.google.com/docs/functions/get-started
//
//// exports.helloWorld = onRequest((request, response) => {
////   logger.info("Hello logs!", {structuredData: true});
////   response.send("Hello from Firebase!");
//// });
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { x25519 } = require('x25519'); // Use a suitable library for X25519

admin.initializeApp();

exports.computeYTimesXPubPK = functions.https.onCall(async (data, context) => {
  const uid = data.uid;
  const docRef = admin.firestore().collection('usersPreKeyValidations').doc(uid);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new functions.https.HttpsError('not-found', 'Document not found');
  }

  const xPubPK = doc.data()['X times PreKey Public'];
  const y = crypto.randomBytes(32);

  // Compute y * (x * PKa)
  const yTimesXPubPK = x25519(y, xPubPK); // Implement this function using a suitable library

  // Update Firestore with yTimesXPubPK and y
  await docRef.update({
    'Y times X times PreKey Public': yTimesXPubPK,
  });

  return { success: true };
});
