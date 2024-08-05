import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:emailchat/services/auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:x25519/x25519.dart';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class PreKeyValidation{

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _firebaseAuth = AuthService();
  User? getCurrentUser() {
    return _firebaseAuth.getCurrentUser();
  }


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

    Uint8List xInvPubpk = Uint8List(32);

    x25519(xPubpk ,x, pubPK.bytes);
    print(xPubpk);


    BigInt bytesToBigInt(Uint8List bytes) {
      BigInt result = BigInt.zero;
      for (int byte in bytes) {
        result = (result << 8) | BigInt.from(byte);
      }
      return result;
    }

    Uint8List bigIntToBytes(BigInt value) {
      // Convert BigInt to Uint8List (big-endian)
      var hexString = value.toRadixString(16);
      if (hexString.length % 2 != 0) hexString = '0$hexString'; // Ensure even length
      final byteList = List<int>.generate(hexString.length ~/ 2,
              (i) => int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16));
      return Uint8List.fromList(byteList);
    }

    BigInt modInverse(BigInt a, BigInt m) {
      final m0 = m;
      BigInt y = BigInt.zero;
      BigInt x = BigInt.one;

      if (m == BigInt.one) return BigInt.zero;

      while (a > BigInt.one) {
        final q = a ~/ m;
        var t = m;

        m = a % m;
        a = t;
        t = y;

        y = x - q * y;
        x = t;
      }

      if (x < BigInt.zero) x += m0;

      return x;
    }

    Uint8List computeModularInverse(Uint8List input, BigInt modulus) {
      BigInt inputBigInt = bytesToBigInt(input);
      BigInt inverseBigInt = modInverse(inputBigInt, modulus);
      Uint8List inverseBytes = bigIntToBytes(inverseBigInt);
      return inverseBytes;
    }
    BigInt modulus = BigInt.parse(
        '7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed', // Modulus for Curve25519
        radix: 16);

    handleServerResponse(Uint8List yx) async {
      Uint8List inverseX = computeModularInverse(x, modulus);
      x25519(xInvPubpk, inverseX,yx);
      final yTimesPK = {
        'Y times PreKey Public' : base64Encode(xInvPubpk),
      };
      await _firestore.collection('usersPreKeyValidations').doc(uid).update(yTimesPK);
    }





    final xTimesPK = {
      'PreKey Public' : base64Encode(pubPK.bytes),
      'X times PreKey Public' : base64Encode(xPubpk),
      'Time Stamp' : timeStamp,
    };

    await _firestore.collection('usersPreKeyValidations').doc(uid).set(xTimesPK);

    User? user = await getCurrentUser();
    if (user == null) {
      print('User is not authenticated');
      return;
    }

    try {
    // Call the cloud function
    HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('computeYTimesXPubPK');
    final response = await callable.call({'uid': uid});

    if (response.data['success']) {
      Uint8List yxpubBytes = base64Decode(response.data['yxpub']);
      await handleServerResponse(yxpubBytes);
      print('Cloud function 1 executed successfully');

    } else {
      print('Cloud function execution failed');
    }
  } catch (e) {
      print('Error calling cloud function: $e');
    }

    try {
      // Call the cloud function
      HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('verifyYTimesPubPK');
      final response = await callable.call({'uid': uid});

      if (response.data['success']) {

        print('Cloud function 2 executed successfully');

      } else {
        print('Cloud function execution failed');
      }
    } catch (e) {
      print('Error calling cloud function: $e');
    }
  }



}
