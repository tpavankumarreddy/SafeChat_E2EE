import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionHelper {
  final AesCtr _aes = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);

  Future<Map<String, dynamic>> encryptMessage(String message, SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = _aes.newNonce();

    final encrypted = await _aes.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'cipherText': base64Encode(encrypted.cipherText),
      'nonce': base64Encode(encrypted.nonce),
    };
  }

  Future<String> decryptMessage(String cipherTextBase64, String nonceBase64, SecretKey secretKey) async {
    try {
      // Decode Base64 strings
      final cipherText = base64Decode(cipherTextBase64);
      final nonce = base64Decode(nonceBase64);

      // Create an empty MAC to satisfy the requirement of SecretBox
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

      return utf8.decode(decrypted);
    } catch (e) {
      print('Error during decryption: $e');
      throw e;
    }
  }
}
