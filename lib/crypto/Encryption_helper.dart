import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:sm_crypto/sm_crypto.dart'; // Import SM4 library
import 'package:blowfish/blowfish.dart';

class EncryptionHelper {
  final AesCtr _aes = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);
  final Chacha20 _chacha20 = Chacha20(macAlgorithm: MacAlgorithm.empty);

  // Method to select encryption algorithm
  Future<Map<String, dynamic>> encryptMessage(String message,
      SecretKey secretKey, {required String algorithm}) async {

    final keyBytes = await secretKey.extract();

    if (algorithm == 'AES') {
      return _encryptAES(message, secretKey);
    } else if (algorithm == 'ChaCha20') {
      return _encryptChaCha20(message, secretKey);
    } else if (algorithm == 'SM4') {
      return _encryptSM4(message, secretKey);
    } else if (algorithm == 'Blowfish') {
      return _encryptBlowfish(message, keyBytes.bytes);
    } else {
      throw UnsupportedError('Encryption algorithm not supported');
    }
  }

  Future<String> decryptMessage(String cipherTextBase64, String nonceBase64,
      SecretKey secretKey, {required String algorithm}) async {
    final keyBytes = await secretKey.extract();

    if (algorithm == 'AES') {
      return _decryptAES(cipherTextBase64, nonceBase64, secretKey);
    } else if (algorithm == 'ChaCha20') {
      return _decryptChaCha20(cipherTextBase64, nonceBase64, secretKey);
    } else if (algorithm == 'SM4') {
      return _decryptSM4(cipherTextBase64, nonceBase64, secretKey);
    }  else if (algorithm == 'Blowfish') {
      return _decryptBlowfish(cipherTextBase64, keyBytes.bytes);
    } else {
      throw UnsupportedError('Decryption algorithm not supported');
    }
  }

  // AES encryption
  Future<Map<String, dynamic>> _encryptAES(String message,
      SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = await _aes.newNonce();

    final encrypted = await _aes.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'cipherText': base64Encode(encrypted.cipherText),
      'nonce': base64Encode(nonce),
    };
  }

  // AES decryption
  Future<String> _decryptAES(String cipherTextBase64, String nonceBase64,
      SecretKey secretKey) async {
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
  Future<Map<String, dynamic>> _encryptChaCha20(String message,
      SecretKey secretKey) async {
    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final nonce = await _chacha20.newNonce();

    final encrypted = await _chacha20.encrypt(
      messageBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'cipherText': base64Encode(encrypted.cipherText),
      'nonce': base64Encode(nonce),
    };
  }

  // ChaCha20 decryption
  Future<String> _decryptChaCha20(String cipherTextBase64, String nonceBase64,
      SecretKey secretKey) async {
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

  Future<Map<String, dynamic>> _encryptSM4(String message, SecretKey secretKey) async {
    final messageBytes = utf8.encode(message); // Convert message to bytes
    final keyBytes = await secretKey.extractBytes(); // Extract key bytes

    // Add zero padding
    final blockSize = 16; // Block size for SM4
    final paddingLength = blockSize - (messageBytes.length % blockSize);
    final paddedMessageBytes = Uint8List.fromList(
      [...messageBytes, ...List.filled(paddingLength, 0)],
    );

    // Generate a random IV (nonce) with 16 bytes
    final nonce = Uint8List(16);
    final random = Random.secure();
    for (int i = 0; i < 16; i++) {
      nonce[i] = random.nextInt(256);
    }

    // Convert data to hexadecimal format for SM4 compatibility
    final keyHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final ivHex = nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final messageHex = paddedMessageBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    print('KeyHex: $keyHex');
    print('IVHex: $ivHex');

    // Encrypt using SM4
    final cipherTextHex = SM4.encrypt(
      data: messageHex,
      key: keyHex,
      mode: SM4CryptoMode.CBC,
      iv: ivHex,
    );

    return {
      'cipherText': cipherTextHex, // Store as-is (hex string)
      'nonce': base64Encode(nonce), // Base64 encode the nonce
    };
  }
  Future<String> _decryptSM4(String cipherTextHex, String nonceBase64, SecretKey secretKey) async {
    final keyBytes = await secretKey.extractBytes();
    final nonce = base64Decode(nonceBase64);

    // Convert the key and IV to hex
    final keyHex = keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final ivHex = nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // print('CipherTextHex: $cipherTextHex');
    // print('KeyHex: $keyHex');
    // print('IVHex: $ivHex');

    try {
      // Decode the ciphertext
      final cipherTextBytes = Uint8List.fromList(
        List.generate(
          cipherTextHex.length ~/ 2,
              (i) => int.parse(cipherTextHex.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );

      //print('CipherTextBytes Length: ${cipherTextBytes.length}');
      if (cipherTextBytes.length % 16 != 0) {
        throw FormatException('CipherText length is not a multiple of 16 bytes.');
      }

      // Decrypt using SM4
      final plainTextHex = SM4.decrypt(
        data: cipherTextHex,
        key: keyHex,
        mode: SM4CryptoMode.CBC,
        iv: ivHex,
      );

      // Convert hex string back to bytes
      final plainTextBytes = Uint8List.fromList(
        List.generate(
          plainTextHex.length ~/ 2,
              (i) => int.parse(plainTextHex.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );

      // Remove zero padding
      final unpaddedPlainTextBytes = plainTextBytes.sublist(
        0,
        plainTextBytes.lastIndexWhere((b) => b != 0) + 1,
      );

      //print('Decrypted and Unpadded bytes: $unpaddedPlainTextBytes');
      return utf8.decode(unpaddedPlainTextBytes); // Decode to original message
    } catch (e) {
      print('Error decrypting message: $e');
      throw FormatException('Decryption failed: $e');
    }
  }

  // Blowfish encryption
  Map<String, dynamic> _encryptBlowfish(String message, List<int> keyBytes) {
    if (message.isEmpty) {
      throw ArgumentError('Message content is missing');
    }
    if (keyBytes.isEmpty || keyBytes.length < 4) {
      throw ArgumentError('Invalid Blowfish key provided');
    }

    final plaintextBytes = utf8.encode(message);
    final blowfish = newBlowfish(keyBytes);

    final encrypted = blowfish.encryptECB(plaintextBytes);

    return {
      'cipherText': base64Encode(encrypted),
      'nonce': '', // ECB mode doesn't require nonce
    };
  }

// Blowfish decryption
  String _decryptBlowfish(String cipherTextBase64, List<int> keyBytes) {
    if (cipherTextBase64.isEmpty) {
      throw ArgumentError('Cipher text is missing');
    }
    if (keyBytes.isEmpty || keyBytes.length < 4) {
      throw ArgumentError('Invalid Blowfish key provided');
    }

    final cipherText = base64Decode(cipherTextBase64);
    final blowfish = newBlowfish(keyBytes);

    final decryptedBytes = blowfish.decryptECB(cipherText);

    return utf8.decode(decryptedBytes);
  }





}