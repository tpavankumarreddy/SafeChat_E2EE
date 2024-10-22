import 'package:SafeChat/crypto/pre_key_validation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'dart:convert';

class KeyGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> generateAndStoreKeys(String uid, String email, String otp) async {
    final algorithm = crypto.X25519();
    final identityKeyValidator = IdentityKeyValidation();

    // Seed generation for identity key
    final iSeed = utf8.encode('$uid++$email++$otp');
    final List<int> finalISeed = (await crypto.Sha256().hash(iSeed)).bytes;

    // Generate Identity Key Pair
    final identityKeyPair = await algorithm.newKeyPairFromSeed(finalISeed);
    final identityKeyPublic = await identityKeyPair.extractPublicKey();

    // Fetch the server's public key from Firestore
    final serverPublicKey = await getServerPublicKey();

    // Seed generation for prekey (if still needed, else can be removed)
    final pKSeed = utf8.encode('$uid++$email++$otp++${DateTime.now()}');
    final List<int> finalPKSeed = (await crypto.Sha256().hash(pKSeed)).bytes;

    // Generate Signed PreKey Pair (if still needed)
    final preKeyPair = await algorithm.newKeyPairFromSeed(finalPKSeed);
    final preKeyPublic = await preKeyPair.extractPublicKey();

    // Generate One-Time PreKeys (if needed)
    final oneTimePreKeys = <crypto.SimpleKeyPair>[];
    final oneTimePreKeysPublic = <crypto.SimplePublicKey>[];

    for (int i = 0; i < 100; i++) {
      final oneTimeKeyPair = await algorithm.newKeyPair();
      oneTimePreKeys.add(oneTimeKeyPair);
      oneTimePreKeysPublic.add(await oneTimeKeyPair.extractPublicKey());
    }

    // Perform identity key validation with only the required arguments
    await identityKeyValidator.validateIdentityKey(
      identityKeyPublic,
      uid,
      identityKeyPair, // Pass the client's identity key pair
      email,
    );

    // Store private keys in secure storage
    await _secureStorage.write(
            key: 'identityKeyPairPrivate$email',
        value: base64Encode(await identityKeyPair.extractPrivateKeyBytes())
    );
    await _secureStorage.write(
        key: 'identityKeyPairPublic$email',
        value: base64Encode(identityKeyPublic.bytes)
    );
    await _secureStorage.write(
        key: 'preKeyPairPrivate$email',
        value: base64Encode(await preKeyPair.extractPrivateKeyBytes())
    );
    await _secureStorage.write(
        key: 'preKeyPairPublic$email',
        value: base64Encode(preKeyPublic.bytes)
    );

    // Store one-time prekeys in secure storage
    for (int i = 0; i < oneTimePreKeys.length; i++) {
      await _secureStorage.write(
          key: 'oneTimePreKeyPairPrivate$email$i',
          value: base64Encode(await oneTimePreKeys[i].extractPrivateKeyBytes())
      );
      await _secureStorage.write(
          key: 'oneTimePreKeyPairPublic$email$i',
          value: base64Encode(oneTimePreKeysPublic[i].bytes)
      );
    }

    // Store public keys in Firestore
    await _firestore.collection("user's").doc(uid).update({
      'identityKey': base64Encode(identityKeyPublic.bytes),
      'preKey': base64Encode(preKeyPublic.bytes),
      'oneTimePrekeys': oneTimePreKeysPublic.map((key) => base64Encode(key.bytes)).toList(),
      'email': email,
      'timeStamp': DateTime.now(),
    });
  }

  Future<crypto.SimplePublicKey> getServerPublicKey() async {
    // Fetch the public key from Firestore
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('server_keys')
          .doc('bMOs2lASMyLAAGOBo35W') // This is the document ID you're fetching
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        final publicKeyString = data?['public_key'];

        if (publicKeyString != null) {
          // Convert the plain text public key string to bytes.
          final publicKeyBytes = utf8.encode(publicKeyString);

          final serverPublicKey = crypto.SimplePublicKey(
            publicKeyBytes,
            type: crypto.KeyPairType.x25519,
          );

          print('Successfully fetched server public key');
          return serverPublicKey;
        } else {
          throw Exception('Public key not found in Firestore');
        }
      } else {
        throw Exception('Server public key document does not exist');
      }
    } catch (e) {
      print('Error fetching server public key: $e');
      throw Exception('Failed to retrieve server public key from Firestore');
    }
  }
}
