import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionHelper {
  final _aes = AesCtr.with128bits(macAlgorithm: MacAlgorithm.empty);

    Future<Map<String, dynamic>> encryptMessage(String message, SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = _aes.newNonce();

    final encrypted = await _aes.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'cipherText': encrypted.cipherText,
      'nonce': nonce,
    };
  }

    Future<String> decryptMessage(List<int> cipherText, List<int> nonce, SecretKey secretKey) async {
    final encryptedData = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac.empty,
    );

    final decrypted = await _aes.decrypt(
      encryptedData,
      secretKey: secretKey,
    );

    return utf8.decode(decrypted);
  }


}
