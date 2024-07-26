import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';


class KeyGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();


  Future<void> generateAndStoreKeys(String uid, String email, String otp) async {
 
    final algorithm = X25519();

    final ed25519 = Ed25519();




    final iSeed = utf8.encode('$uid++$email++$otp');
    final List<int> finalISeed = (await Sha256().hash(iSeed)).bytes;

    // Generate Identity Key
    final identityKeyPair = await algorithm.newKeyPairFromSeed(finalISeed);
    final identityKeyPublic = await identityKeyPair.extractPublicKey();
    //final identityKeyPrivate = await identityKeyPair.extractPrivateKeyBytes();

    final now = DateTime.now();

    final pKSeed = utf8.encode('$uid++$email++$otp++$now');
    final List<int> finalPKSeed = (await Sha256().hash(pKSeed)).bytes;


    // Generate Signed PreKey Pair
    final preKeyPair = await algorithm.newKeyPairFromSeed(finalPKSeed);
    final preKeyPublic = await preKeyPair.extractPublicKey();

    final signature = await ed25519.sign(
      preKeyPublic.bytes,
      keyPair: identityKeyPair
    );


    // Generate One-Time PreKeys
    final oneTimePreKeys = <SimpleKeyPair>[];
    final oneTimePreKeysPublic = <SimplePublicKey>[];
    for (int i = 0; i < 100; i++) {
      final oneTimeKeyPair = await algorithm.newKeyPair();
      oneTimePreKeys.add(oneTimeKeyPair);
      oneTimePreKeysPublic.add(await oneTimeKeyPair.extractPublicKey());
    }

    await _secureStorage.write(
        key: 'identityKeyPairPrivate', value: base64Encode(await identityKeyPair.extractPrivateKeyBytes()));
    await _secureStorage.write(
        key: 'identityKeyPairPublic', value: base64Encode(identityKeyPublic.bytes));
    await _secureStorage.write(
        key: 'signedPreKeyPairPrivate', value: base64Encode(await preKeyPair.extractPrivateKeyBytes()));
    await _secureStorage.write(
        key: 'signedPreKeyPairPublic', value: base64Encode(preKeyPublic.bytes));
    for (int i = 0; i < oneTimePreKeys.length; i++) {
      await _secureStorage.write(
          key: 'oneTimePreKeyPairPrivate$i', value: base64Encode(await oneTimePreKeys[i].extractPrivateKeyBytes()));
      await _secureStorage.write(
          key: 'oneTimePreKeyPairPublic$i', value: base64Encode(oneTimePreKeysPublic[i].bytes));
    }

    //await _secureStorage.write(key: 'signedPreKey signature', value: base64Encode(signature))

    // Store public keys in Firestore database
    await _firestore.collection("user's").doc(uid).update({
      'identityKey': base64Encode(identityKeyPublic.bytes),
      'signedPreKey': base64Encode(preKeyPublic.bytes),
      'oneTimePrekeys': oneTimePreKeysPublic.map((key) => base64Encode(key.bytes)).toList(),
      'signedPreKey signature' : signature,
      'email': email,
    });
  }
}
