import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:x25519/x25519.dart';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class PreKeyValidation{

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Future<void> validatePreKey(crypto.SimplePublicKey pubPK, String uid)async{

    Uint8List generateSecureRandomScalar() {
      final secureRandom = Random.secure();
      final scalar = Uint8List(32);
      for (int i = 0; i < scalar.length; i++) {
        scalar[i] = secureRandom.nextInt(256);
      }
      return scalar;
    }

    final timeStamp = DateTime.now();


    Uint8List x = generateSecureRandomScalar();
    print(x);
    print(pubPK.bytes);
    Uint8List xPubpk = Uint8List(32);


    x25519(xPubpk ,x, pubPK.bytes);
    print(xPubpk);

    final xTimesPK = {
      'PreKey Public' : base64Encode(pubPK.bytes),
      'X times PreKey Public' : base64Encode(xPubpk),
      'Time Stamp' : timeStamp,
    };

    await _firestore.collection('usersPreKeyValidations').doc(uid).set(xTimesPK);

    // Call the cloud function
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('computeYTimesXPubPK');
    final response = await callable.call({'uid': uid});

    if (response.data['success']) {
      print('Cloud function executed successfully');
      //await handleServerResponse(uid, x);
    } else {
      print('Cloud function execution failed');
    }
  }




}
