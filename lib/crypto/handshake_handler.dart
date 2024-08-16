import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'X3DHHelper.dart';
import 'get_prekeybundle.dart';

class HandshakeHandler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PreKeyBundleRetriever _preKeyBundleRetriever = PreKeyBundleRetriever();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> sendHandshakeMessage(String senderUid, String receiverUid, String receiverEmail, int indexOTPK) async {



    // Create handshake message
    final handshakeMessage = {
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'oneTimePreKeyIndex': indexOTPK,
    };

    // Send handshake message
    await _firestore.collection('handshakes').doc('$receiverUid-$senderUid').set(handshakeMessage);
  }

  Future<Map<String, dynamic>?> receiveHandshakeMessage(String localUid, String remoteUid) async {
    final docSnapshot = await _firestore.collection('handshakes').doc('$localUid-$remoteUid').get();
    if (docSnapshot.exists) {
      return docSnapshot.data();
    }
    return null;
  }

  Future<void> handleReceivedHandshakeMessage(String email, String remoteEmail, Map<String, dynamic> handshakeMessage) async {
    final x3dhHelper = X3DHHelper();

    // Perform X3DH with the received handshake message
    final x3dhResult = await x3dhHelper.performX3DHKeyAgreementForBob(
      email, remoteEmail ,handshakeMessage['oneTimePreKeyIndex']
    );

    SecretKey sharedSecret = x3dhResult['sharedSecret'];
   // int randomIndex = x3dhResult['randomIndex'];

    // Store the secret key securely
    List<int> sharedSecretBytes = await sharedSecret.extractBytes();
    await _secureStorage.write(key: 'shared_Secret_With_$remoteEmail', value: base64Encode(sharedSecretBytes));
    print("Shared secret: $sharedSecretBytes");
    print('shared_Secret_With_$remoteEmail $base64Decode(secretKey1!)');

  }
}
