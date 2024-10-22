import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pinenacl/api.dart';
import 'package:pinenacl/api/authenticated_encryption.dart';
import 'package:pinenacl/api/signatures.dart';
import 'package:pinenacl/digests.dart';
import 'package:pinenacl/ed25519.dart';
import 'package:pinenacl/encoding.dart';
import 'package:pinenacl/key_derivation.dart';
import 'package:pinenacl/message_authentication.dart';
import 'package:pinenacl/tweetnacl.dart';
import 'package:pinenacl/x25519.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IdentityKeyValidation {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _firebaseAuth = AuthService();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  User? getCurrentUser() {
    User? user = _firebaseAuth.getCurrentUser();
    print('Current User: $user');
    return user;
  }

  Uint8List generateSecureRandomNonce() {
    final secureRandom = Random.secure();
    final nonce = Uint8List(24); // Change the nonce size as needed
    for (int i = 0; i < nonce.length; i++) {
      nonce[i] = secureRandom.nextInt(256);
    }
    print('Generated nonce: ${base64Encode(nonce)}');
    return nonce;
  }

  // Fetch the user's private key from Flutter Secure Storage using email
  Future<PrivateKey> fetchUserPrivateKey(String email) async {
    try {
      String? privateKeyBase64 = await _secureStorage.read(
          key: 'identityKeyPairPrivate$email');
      if (privateKeyBase64 != null) {
        print(
            'Fetched user private key from secure storage: $privateKeyBase64');
        return PrivateKey(base64Decode(privateKeyBase64));
      } else {
        throw Exception(
            'Private key not found in secure storage for email: $email');
      }
    } catch (e) {
      print('Error fetching user private key from secure storage: $e');
      throw Exception('Failed to fetch private key');
    }
  }

  Uint8List hexToUint8List(String hex) {
    final length = hex.length ~/ 2;
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  EncryptedMessage encryptNonce(Uint8List nonce, PrivateKey myPrivateKey,
      PublicKey theirPublicKey) {
    final box = Box(myPrivateKey: myPrivateKey, theirPublicKey: theirPublicKey);
    final encryptedNonce = box.encrypt(nonce);
    print('Encrypted Nonce: ${base64Encode(encryptedNonce.cipherText)}');
    return encryptedNonce;
  }

  Uint8List decryptMessage(Uint8List encryptedMessage, Uint8List nonce,
      PrivateKey myPrivateKey, PublicKey theirPublicKey) {
    final box = Box(myPrivateKey: myPrivateKey, theirPublicKey: theirPublicKey);
    try {
      // Debugging information
      print('Starting decryption...');
      print('Encrypted message size: ${encryptedMessage.length}');
      print('Nonce: ${nonce}');
      print('Nonce size: ${nonce.length}');
      print('My private key: ${base64Encode(myPrivateKey)}');
      print('Their public key: ${base64Encode(theirPublicKey)}');

      if (nonce.length != 24) { // Assuming nonce size is 24 bytes
        throw Exception('Invalid nonce size: ${nonce.length}');
      }

      final decryptedMessage = box.decrypt(
          EncryptedMessage(cipherText: encryptedMessage, nonce: nonce));
      print('Decrypted message: ${base64Encode(
          decryptedMessage)}'); // Log the decrypted message
      return decryptedMessage;
    } catch (e) {
      print('Decryption error: $e');
      throw Exception('Failed to decrypt message');
    }
  }

  Future<void> validateIdentityKey(crypto.SimplePublicKey identityKey,
      String uid, crypto.SimpleKeyPair clientKeyPair, String email) async {
    final timeStamp = DateTime.now();
    final identityKeyData = {
      'Identity Key': base64Encode(identityKey.bytes),
      'Timestamp': timeStamp,
    };
    print('Saving identity key data to Firestore for UID: $uid');

    await _firestore.collection('identityKeyValidations').doc(uid).set(
        identityKeyData);
    print('Identity key data saved successfully');

    User? user = getCurrentUser();
    if (user == null) {
      print('User is not authenticated');
      return;
    }

    // Generate nonce
    Uint8List nonce = generateSecureRandomNonce();

    try {
      // Fetch the user's private key using the email
      PrivateKey myPrivateKey = await fetchUserPrivateKey(
          email); // Use email here

      // Calling cloud function userpub1
      print('Calling cloud function userpub1 with UID: $uid');
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'userpub1');
      final response = await callable.call({'uid': uid});
      print('Response from userpub1: ${response.data}');

      if (response.data['success']) {
        print('Cloud function 1 executed successfully');

        // Decode the received encrypted nonce
        Uint8List encryptedNonceData = base64Decode(
            response.data['encryptedNonce']);
        print('Encrypted Nonce Data: ${base64Encode(encryptedNonceData)}');

        // Extract the received encryption nonce
        Uint8List receivedEncryptionNonce = base64Decode(
            response.data['encryptionNonce']);
        print('Received Encryption Nonce: ${base64Encode(
            receivedEncryptionNonce)}');

        if (encryptedNonceData.length <= 24) {
          print('Error: Encrypted nonce data is too short.');
          return;
        }

        // Get the global public key from the response
        String globalPublicKeyBase64 = response.data['globalPublicKey'];
        Uint8List globalPublicKeyBytes = base64Decode(globalPublicKeyBase64);
        PublicKey globalPublicKey = PublicKey(globalPublicKeyBytes);

        // Decrypt the nonce using the received encrypted message
        Uint8List decryptedNonce = decryptMessage(
            encryptedNonceData, receivedEncryptionNonce, myPrivateKey,
            globalPublicKey);
        print('Decrypted Nonce: ${base64Encode(decryptedNonce)}');

        // Re-encrypt the nonce to send back
        EncryptedMessage reEncryptedNonce = encryptNonce(
            decryptedNonce, myPrivateKey, globalPublicKey);
        print(
            'Re-encrypted Nonce: ${base64Encode(reEncryptedNonce.cipherText)}');

        // Call cloud function userpub2
        print('Calling cloud function userpub2 with UID: $uid');
        HttpsCallable callable2 = FirebaseFunctions.instance.httpsCallable(
            'userpub2');
        final response2 = await callable2.call({
          'uid': uid,
          'encryptedNonce': base64Encode(reEncryptedNonce.cipherText),
        });

        print('Response from userpub2: ${response2.data}');
        if (response2.data['success']) {
          print('Cloud function 2 executed successfully');
          print('Verification status: ${response2.data['verified']}');
        } else {
          print(
              'Cloud function 2 execution failed: ${response2.data['error']}');
        }
      } else {
        print('Cloud function 1 execution failed');
      }
    } catch (e) {
      print('Error calling cloud function: $e');
    }
  }
}