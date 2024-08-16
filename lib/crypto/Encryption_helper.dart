import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionHelper {
  final AesCtr _aes = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  Future<Map<String, dynamic>> encryptMessage(String message, SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = await _aes.newNonce();

    // print('Encrypting message: $message');
    // print('Message bytes: $messageBytes');
    // print('Nonce: $nonce');

    final encrypted = await _aes.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final cipherText = base64Encode(encrypted.cipherText);
    final encodedNonce = base64Encode(encrypted.nonce);

    // print('CipherText: $cipherText');
    // print('Encoded Nonce: $encodedNonce');

    return {
      'cipherText': cipherText,
      'nonce': encodedNonce,
    };
  }

  Future<String> decryptMessage(String cipherTextBase64, String nonceBase64, SecretKey secretKey) async {
    try {
      final cipherText = base64Decode(cipherTextBase64);
      final nonce = base64Decode(nonceBase64);

      // print('Decrypting message...');
      // print('Cipher Text (decoded): $cipherText');
      // print('Nonce (decoded): $nonce');

      final mac = Mac.empty;

      final encryptedData = SecretBox(
        cipherText,
        nonce: nonce,
        mac: mac,
      );

      final decrypted = await _aes.decrypt(
        encryptedData,
        secretKey: secretKey,
      );

      final message = utf8.decode(decrypted);
      //print('Decrypted message: $message');

      return message;
    } catch (e) {
     // print('Error during decryption: $e');
      throw e;
    }
  }

}
