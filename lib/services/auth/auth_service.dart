import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailchat/crypto/key_gen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign in
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);

      await initializeKeys(userCredential.user!.uid);


      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Sign up
  Future<UserCredential> signUpWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);

      await _firestore.collection("user's").doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
      });

      // Generate and store cryptographic keys
      await KeyGenerator().generateAndStoreKeys(userCredential.user!.uid,email);

      print("Keys generated and stored in firestone database.");
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  // Sign out
  Future<void> signOut() async {
    return await _auth.signOut();
  }

  Future<void> initializeKeys(String userId) async {
    final userDoc = await _firestore.collection("user's").doc(userId).get();
    if (userDoc.exists) {
      // Retrieve and store public keys if they are not already in secure storage
      if (await _secureStorage.read(key: 'identityKeyPairPublic') == null) {
        await _secureStorage.write(key: 'identityKeyPairPublic', value: userDoc['identityKey']);
      }
      if (await _secureStorage.read(key: 'signedPreKeyPairPublic') == null) {
        await _secureStorage.write(key: 'signedPreKeyPairPublic', value: userDoc['signedPreKey']);
      }
      final oneTimePreKeys = userDoc['oneTimePreKeys'] as List;
      for (int i = 0; i < oneTimePreKeys.length; i++) {
        if (await _secureStorage.read(key: 'oneTimePreKeyPairPublic_$i') == null) {
          await _secureStorage.write(key: 'oneTimePreKeyPairPublic_$i', value: oneTimePreKeys[i]);
        }
      }
    }
  }

}
