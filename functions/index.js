const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nacl = require("tweetnacl");
nacl.util = require("tweetnacl-util");

admin.initializeApp();
/**
 * Retrieves the server's public and private keys from Firestore.
 * @return {Promise<Object>} - A promise that res private keys.
 * @throws {functions.https.HttpsError} - Throws an error i.
 */
async function getServerKeys() {
  const docRef = admin.firestore().collection("server_keys")
      .doc("vZmAicjwUeWBJQeKttBL");
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Server keys not found");
  }

  return {
    publicKey: nacl.util.decodeBase64(doc.data().public_key),
    privateKey: nacl.util.decodeBase64(doc.data().private_key),
  };
}


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

  const {publicKey, privateKey} = await getServerKeys();
  console.log(publicKey);
  const nonce = nacl.randomBytes(24);
  const xPubPK = nacl.util.decodeBase64(doc.data()["PreKey Public"]);

  const encryptedNonce = nacl.box(
      nonce,
      nonce, // The nonce should be reused here for box and box.open
      xPubPK,
      privateKey,
  );

  await docRef.update({
    "Encrypted Nonce": nacl.util.encodeBase64(encryptedNonce),
  });

  return {success: true, nonce: nacl.util.encodeBase64(nonce)};
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

  const {privateKey} = await getServerKeys();

  const receivedNonceMinusOne = nacl.util.decodeBase64(data.nonceMinusOne);
  const encryptedNonce = nacl.util.decodeBase64(doc.data()["Encrypted Nonce"]);

  const nonce = nacl.randomBytes(24);

  const decryptedNonce = nacl.box.open(
      encryptedNonce,
      nonce, // The same nonce used during encryption
      receivedNonceMinusOne,
      privateKey,
  );

  let isValid = false;
  if (decryptedNonce) {
    const expectedNonceMinusOne=decryptedNonce.map((byte) => (byte - 1) & 0xFF);
    isValid= nacl.util.encodeBase64(expectedNonceMinusOne)===data.nonceMinusOne;
  }

  await docRef.update({
    "PreKey Verification Status": isValid ? "verified" : "not verified",
  });

  return {success: true, verified: isValid};
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
    console.error("Error 1checking email:", error);
    throw new functions.https.HttpsError("internal",
        "Unable to check email existence");
  }
});

exports.initiateX3DH = functions.https.onCall(async (data, context) => {
  console.log("initiateX3DH function started");

  // Extracting data
  const {email, aliceEmail, aliceIdentityKey, alicePreKey}=data;

  // Validate inputs
  if (!email || !aliceEmail || !aliceIdentityKey || !alicePreKey) {
    throw new functions.https.HttpsError("invalid-argument",
        "Missing required parameters.");
  }

  console.log("Received data:", {
    email,
    aliceEmail,
    aliceIdentityKeyType: typeof aliceIdentityKey,
    alicePreKeyType: typeof alicePreKey,
    aliceIdentityKeyLength: aliceIdentityKey.length,
    alicePreKeyLength: alicePreKey.length,
  });

  // Generate random index
  const i = Math.floor(Math.random() * 100);
  console.log(i);
  // Fetch Bob's keys from Firestore
  const userQuerySnapshot = await admin.firestore()
      .collection("user's")
      .where("email", "==", email)
      .get();

  if (userQuerySnapshot.empty) {
    throw new functions.https.HttpsError("not-found",
        "No user found with the given email.");
  }

  const userDoc = userQuerySnapshot.docs[0];
  const bobIdentityKey = userDoc.get("identityKey");
  const bobPreKey = userDoc.get("preKey");
  const oneTimePreKeys = userDoc.get("oneTimePrekeys");
  console.log(bobIdentityKey);
  const bobOneTimePreKey = oneTimePreKeys[i];
  console.log("Selected OTP Key:", bobOneTimePreKey);

  if (!bobIdentityKey) {
    throw new functions.https.HttpsError("not-found",
        "Required Bob's Identity key is missing.");
  }
  if (!bobPreKey) {
    throw new functions.https.HttpsError("not-found",
        "Required Bob's Pre key is missing.");
  }

  if (!bobOneTimePreKey) {
    throw new functions.https.HttpsError("not-found",
        "Required Bob's OTP key is missing.");
  }


  // Encrypt keys
  //  let encryptedPreKey;
  //  let encryptedOneTimePreKey;
  //
  //  try {
  //    encryptedPreKey = await encryptWithPublicKey(bobPreKey, alicePreKey);
  //    encryptedOneTimePreKey = await encryptWithPublicKey(bobOneTimePreKey,
  //        alicePreKey);
  //  } catch (error) {
  //    console.error("Encryption failed:", error);
  //    throw new functions.https.HttpsError("internal", "Encryption failed.");
  //  }

  // Store pending message in Firestore
  try {
    await admin.firestore().collection("pendingMessages")
        .doc(`${email}_${aliceEmail}`)
        .set({
          aliceIdentityKey: aliceIdentityKey,
          alicePreKey: alicePreKey,
          index: i,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
  } catch (error) {
    console.error("Failed to store pending message:", error);
    throw new functions.https.HttpsError("internal",
        "Failed to store pending message.");
  }

  // Return the encrypted keys and index
  return {
    bobIdentityKey,
    bobPreKey,
    bobOneTimePreKey,
    index: i,
  };
});

//    /**
//     * Encrypts data using a given public key.
//     *
//     * @param {string} publicKey - The public key used for encryption.
//     * @param {string} data - The data to be encrypted.
//     * @return {string} The encrypted data, encoded in base64.
//     */
//    function encryptWithPublicKey(publicKey, data) {
//      try {
//        const pemPublicKey = convertToPem(publicKey);
//        console.log(pemPublicKey);
//        const buffer = Buffer.from(data, "utf8");
//        const encrypted = publicEncrypt(pemPublicKey, buffer);
//        return encrypted.toString("base64");
//      } catch (error) {
//        console.error("Encryption failed:", error);
//        throw new functions.https.HttpsError("internal","Encryption failed.");
//      }
//    }
//    /**
//     * Converts public key into PEM format.
//     *
//     * @param {string} publicKeyBase64 - The public key used for encryption.
//     * @return {string} The encrypted data, encoded in base64.
//     */
//    function convertToPem(publicKeyBase64) {
//      // Insert line breaks every 64 characters for PEM format
//      const formattedKey = publicKeyBase64.match(/.{1,64}/g).join("\n");
//
//      // Wrap with PEM headers and footers
//      const pemKey =
//      `-----BEGIN-----\n${formattedKey}\n-----END PUBLIC KEY-----\n`;
//
//      return pemKey;
//    }


exports.retrieveAliceKeys = functions.https.onCall(async (data, context) => {
  const bobEmail = data.bobEmail;
  const aliceEmail = data.aliceEmail;
  console.log(bobEmail);
  console.log(aliceEmail);
  // console.log(${aliceEmail}_${bobEmail});
  const docRef = admin.firestore()
      .collection("pendingMessages")
      .doc(`${aliceEmail}_${bobEmail}`);


  const doc = await docRef.get();

  if (doc.exists) {
    const aliceData = doc.data();
    console.log("exits");
    return {
      aliceIdentityKey: aliceData.aliceIdentityKey,
      alicePreKey: aliceData.alicePreKey,
      index: aliceData.index,
      status: "yes",
    };
  } else {
    return {
      status: "No pending messages found for this user.",
    };
  }
});

