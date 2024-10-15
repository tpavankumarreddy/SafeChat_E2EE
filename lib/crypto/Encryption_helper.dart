import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionHelper {
  final AesCtr _aes = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);
  final Chacha20 _chacha20 = Chacha20(macAlgorithm: MacAlgorithm.empty);

  // Method to select encryption algorithm
  Future<Map<String, dynamic>> encryptMessage(String message, SecretKey secretKey, {required String algorithm}) async {
    if (algorithm == 'AES') {
      return _encryptAES(message, secretKey);
    } else if (algorithm == 'ChaCha20') {
      return _encryptChaCha20(message, secretKey);
    } else {
      throw UnsupportedError('Encryption algorithm not supported');
    }
  }

  Future<String> decryptMessage(String cipherTextBase64, String nonceBase64, SecretKey secretKey, {required String algorithm}) async {
    if (algorithm == 'AES') {
      return _decryptAES(cipherTextBase64, nonceBase64, secretKey);
    } else if (algorithm == 'ChaCha20') {
      return _decryptChaCha20(cipherTextBase64, nonceBase64, secretKey);
    } else {
      throw UnsupportedError('Decryption algorithm not supported');
    }
  }

  // AES encryption
  Future<Map<String, dynamic>> _encryptAES(String message, SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = await _aes.newNonce();

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

  // AES decryption
  Future<String> _decryptAES(String cipherTextBase64, String nonceBase64, SecretKey secretKey) async {
    final cipherText = base64Decode(cipherTextBase64);
    final nonce = base64Decode(nonceBase64);

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

  // ChaCha20 encryption
  Future<Map<String, dynamic>> _encryptChaCha20(String message, SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = await _chacha20.newNonce();

    final encrypted = await _chacha20.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'cipherText': base64Encode(encrypted.cipherText),
      'nonce': base64Encode(encrypted.nonce),
    };
  }

  // ChaCha20 decryption
  Future<String> _decryptChaCha20(String cipherTextBase64, String nonceBase64, SecretKey secretKey) async {
    final cipherText = base64Decode(cipherTextBase64);
    final nonce = base64Decode(nonceBase64);

    final encryptedData = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac.empty,
    );

    final decrypted = await _chacha20.decrypt(
      encryptedData,
      secretKey: secretKey,
    );

    return utf8.decode(decrypted);
  }
}
