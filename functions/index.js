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
 * Decrypts the message using the server's private key.
 * @param {Uint8Array} encryptedMessage - The encrypted message.
 * @param {Uint8Array} nonce - The nonce used during encryption.
 * @param {Uint8Array} userPublicKey - The user's public key.
 * @return {Uint8Array} - The decrypted message.
 */
function decryptMessage(encryptedMessage, nonce, userPublicKey) {
  return nacl.box.open(
      encryptedMessage,
      nonce,
      userPublicKey,
      globalKeys.privateKey,
  );
}

/**
 * Encrypts a message (nonce + uid + server id) using the user's
 * @param {Uint8Array} message - The message to be encrypted.
 * @param {Uint8Array} userPublicKey - The user's public key.
 * @return {{encryptedMessage: Uint8Array, encryptionNonce: Uint8Array}}
 */
function encryptMessage(message, userPublicKey) {
  const encryptionNonce = nacl.randomBytes(nacl.box.nonceLength);
  const encryptedMessage = nacl.box(
      message,
      encryptionNonce,
      userPublicKey,
      globalKeys.privateKey,
  );

  return {encryptedMessage, encryptionNonce};
}

// Cloud function to handle the first call (sending the encrypted nonce)
exports.userpub1 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }

  const uid = data.uid;
  const identityKeyRef = admin.firestore()
      .collection("identityKeyValidations").doc(uid);
  const identityDoc = await identityKeyRef.get();

  if (!identityDoc.exists) {
    throw new functions.https.HttpsError("not-found",
        "Identity Key Document not found");
  }

  // Fetch user's public identity key
  const userPublicKeyBase64 = identityDoc.data()["Identity Key"];
  const userPublicKey = base64ToUint8Array(userPublicKeyBase64);

  console.log("UID:", uid);
  console.log("User Public Key:", userPublicKeyBase64);

  // Log the public and private keys of the server
  console.log("Server Global Public Key:",
      uint8ArrayToBase64(globalKeys.publicKey));
  console.log("Server Global Private Key:",
      uint8ArrayToBase64(globalKeys.privateKey));

  // Log the public key size
  console.log("User Public Key Size:", userPublicKey.length);

  // Generate a nonce for concatenation
  const nonceForMessage = nacl.randomBytes(24);
  // Fetch server id from Firestore
  const serverDoc = await admin.firestore().collection("server_keys")
      .doc("bMOs2lASMyLAAGOBo35W").get();
  const serverId = serverDoc.data()["sid"];

  // Concatenate the message with nonce, uid, and server id
  const message =
  new Uint8Array([...nonceForMessage, ...nacl.util.decodeUTF8(uid),
    ...nacl.util.decodeUTF8(serverId)]);

  // Log plain message size and content
  console.log("Plain Message Size:", message.length);
  console.log("Plain Message (nonce + uid + serverId):", message);

  // Encrypt the concatenated string using the user's public key
  const {encryptedMessage, encryptionNonce} =
    encryptMessage(message, userPublicKey);

  // Log encrypted message size and content
  console.log("Encrypted Message Size:", encryptedMessage.length);
  console.log("Encrypted Message:", encryptedMessage);

  // Save the hashed nonce and original nonce to Firestore
  await identityKeyRef.update({
    "HashedNonce": uint8ArrayToBase64(nacl.hash(nonceForMessage)),
    "Nonce": uint8ArrayToBase64(nonceForMessage),
  });

  // Return encrypted message and the nonce used for encryption
  return {
    success: true,
    encryptedNonce: uint8ArrayToBase64(encryptedMessage),
    encryptionNonce: uint8ArrayToBase64(encryptionNonce),
    globalPublicKey: uint8ArrayToBase64(globalKeys.publicKey),
  };
});

// Cloud function to handle the second call (validating by the user)
exports.userpub2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated",
        "The function must be called while authenticated.");
  }

  const uid = data.uid;
  const identityKeyRef = admin.firestore()
      .collection("identityKeyValidations").doc(uid);
  const identityDoc = await identityKeyRef.get();

  if (!identityDoc.exists) {
    throw new functions.https.HttpsError("not-found",
        "Identity Key Document not found");
  }

  // Get the encrypted nonce and user's public identity key from Firestore
  const receivedEncryptedMessage = base64ToUint8Array(data.encryptedNonce);
  const userPublicKeyBase64 = identityDoc.data()["Identity Key"];
  const userPublicKey = base64ToUint8Array(userPublicKeyBase64);

  // Log public key size
  console.log("User Public Key Size:", userPublicKey.length);

  // Retrieve the original nonce used for encryption from Firestore
  const storedNonce = base64ToUint8Array(identityDoc.data()["Nonce"]);

  // Log nonce size
  console.log("Stored Nonce Size:", storedNonce.length);

  // Decrypt the received encrypted message
  const serverDoc = await admin.firestore().collection("server_keys")
      .doc("bMOs2lASMyLAAGOBo35W").get();
  const serverId = serverDoc.data()["sid"];
  const decryptedMessage = decryptMessage(receivedEncryptedMessage,
      storedNonce, userPublicKey);

  // Log decrypted message size and content
  console.log("Decrypted Message Size:", decryptedMessage.length);
  console.log("Decrypted Message:", decryptedMessage);

  // Extract UID, SID, and Nonce from the decrypted message
  const receivedUid = nacl.util.encodeUTF8(decryptedMessage.slice(24, 48));
  const receivedSid = nacl.util.encodeUTF8(decryptedMessage.slice(48));

  if (uid !== receivedUid || serverId !== receivedSid) {
    return {success: false, verified: false, error: "Invalid UID or Server ID"};
  }

  // Hash the received nonce
  const receivedNonce = decryptedMessage.slice(0, 24);
  const receivedNonceHash = nacl.hash(receivedNonce);

  // Log received nonce and hash sizes
  console.log("Received Nonce Size:", receivedNonce.length);
  console.log("Received Nonce Hash Size:", receivedNonceHash.length);

  // Compare with the stored hashed nonce
  const storedNonceHash = base64ToUint8Array(identityDoc.data()["HashedNonce"]);

  const isVerified = storedNonceHash.every((value, index) => value ===
    receivedNonceHash[index]);

  // Log verification result
  console.log("Verification Status:", isVerified);

  // Update verification status in Firestore
  await identityKeyRef.update({
    "Verification": isVerified ? true : false,
  });

  return {success: true, verified: isVerified};
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

