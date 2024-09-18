/* eslint-disable no-unused-vars */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nacl = require("tweetnacl");
nacl.util = require("tweetnacl-util");

// Initialize Firebase Admin
admin.initializeApp();

// Generate keys once and store globally
const globalKeys = (() => {
  const keyPair = nacl.box.keyPair();
  return {
    publicKey: keyPair.publicKey,
    privateKey: keyPair.secretKey,
  };
})();

/**
 * Converts a Uint8Array to a Base64 string.
 * @param {Uint8Array} uint8Array - The Uint8Array to convert.
 * @return {string} - The Base64-encoded string.
 */
function uint8ArrayToBase64(uint8Array) {
  const binaryString = String.fromCharCode.apply(null, uint8Array);
  return Buffer.from(binaryString, "binary").toString("base64");
}

/**
 * Converts a Base64 string to a Uint8Array.
 * @param {string} base64 - The Base64-encoded string to convert.
 * @return {Uint8Array} - The resulting Uint8Array.
 */
function base64ToUint8Array(base64) {
  const binaryString = Buffer.from(base64, "base64").toString("binary");
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes;
}

/**
 * Encrypts a nonce using the provided public key and the server's private key.
 * @param {Uint8Array} nonce - The nonce to be encrypted.
 * @param {Uint8Array} userPublicKey - The user's public key.
 * @return {Uint8Array} - The encrypted nonce.
 */
function encryptNonce(nonce, userPublicKey) {
  // Ensure nonce and userPublicKey are Uint8Array
  if (!(nonce instanceof Uint8Array)) {
    throw new Error("nonce must be a Uint8Array");
  }
  if (!(userPublicKey instanceof Uint8Array)) {
    throw new Error("userPublicKey must be a Uint8Array");
  }
  return nacl.box(
      nonce,
      nacl.randomBytes(nacl.box.nonceLength), // Use a nonce
      userPublicKey,
      globalKeys.privateKey,
  );
}


/**
 * Decrypts the encrypted nonce using the provided.
 * @param {Uint8Array} encryptedNonce - The encrypted nonce.
 * @param {Uint8Array} receivedNonce - The nonce used during encryption.
 * @param {Uint8Array} userPrivateKey - The user's private key.
 * @return {Uint8Array} - The decrypted nonce.
 */
function decryptNonce(encryptedNonce, receivedNonce, userPrivateKey) {
  // Ensure encryptedNonce, receivedNonce, and userPrivateKey are Uint8Array
  if (!(encryptedNonce instanceof Uint8Array)) {
    throw new Error("encryptedNonce must be a Uint8Array");
  }
  if (!(receivedNonce instanceof Uint8Array)) {
    throw new Error("receivedNonce must be a Uint8Array");
  }
  if (!(userPrivateKey instanceof Uint8Array)) {
    throw new Error("userPrivateKey must be a Uint8Array");
  }
  return nacl.box.open(
      encryptedNonce,
      nacl.randomBytes(nacl.box.nonceLength), // Use a fresh nonce
      receivedNonce,
      userPrivateKey,
  );
}


exports.userpub1 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }

  const uid = data.uid;
  const docRef = admin.firestore().collection("usersPreKeyValidations").
      doc(uid);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Document not found");
  }

  const nonce = nacl.randomBytes(24);
  const userPublicKey = new Uint8Array(doc.data()["PreKey Public"]);

  const encryptedNonce = encryptNonce(nonce, userPublicKey);

  await docRef.update({
    "Encrypted Nonce": uint8ArrayToBase64(encryptedNonce),
  });

  return {success: true, nonce: nonce};
});

exports.userpub2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }

  const uid = data.uid;
  const docRef = admin.firestore().collection("usersPreKeyValidations").
      doc(uid);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new functions.https.HttpsError("not-found", "Document not found");
  }

  const receivedNonceMinusOne = data.nonceMinusOne;
  const encryptedNonce = base64ToUint8Array(doc.data()["Encrypted Nonce"]);

  const decryptedNonce = decryptNonce(encryptedNonce,
      nacl.randomBytes(nacl.box.nonceLength), globalKeys.publicKey);

  let isValid = false;
  if (decryptedNonce) {
    const expectedNonceMinusOne = decryptedNonce.map((byte) =>
      (byte - 1) & 0xFF);
    isValid = expectedNonceMinusOne.every((value, index) =>
      value === data.nonceMinusOne[index]);
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
//      -----BEGIN-----\n${formattedKey}\n-----END PUBLIC KEY-----\n;
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
      EphemeralKey: aliceData.EphemeralKey,
      status: "yes",
    };
  } else {
    return {
      status: "No pending messages found for this user.",
    };
  }
});
/* eslint-disable no-unused-vars */

