import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';

class KeyUtility {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Retrieves the master key for the given email from secure storage.
  /// The master key is stored in the format: 'shared_Secret_With_${email}'
  static Future<Uint8List> getMasterKey(String email) async {
    String? masterKeyBase64 = await _secureStorage.read(key: 'shared_Secret_With_$email');
    if (masterKeyBase64 == null) {
      throw Exception("Master key not found for email: $email");
    }
    return base64Decode(masterKeyBase64);
  }

  /// Derives a key of the specified length (in bits) from the master key.
  /// Uses the first or last bits based on the `useFirstBits` flag.
  static Future<Uint8List> deriveKey(String email, int keyLengthBits, {bool useFirstBits = true}) async {
    // Ensure key length is a multiple of 8 (convert bits to bytes)
    if (keyLengthBits % 8 != 0) {
      throw Exception("Key length must be a multiple of 8.");
    }
    final keyLengthBytes = keyLengthBits ~/ 8;

    // Get the master key
    Uint8List masterKey = await getMasterKey(email);

    // Check if the master key is sufficient for the requested length
    if (masterKey.length < keyLengthBytes) {
      throw Exception("Master key is too short for the requested length.");
    }

    // Derive the key based on the requested length and method
    if (useFirstBits) {
      return masterKey.sublist(0, keyLengthBytes);
    } else {
      return masterKey.sublist(masterKey.length - keyLengthBytes);
    }
  }

  /// Utility function to derive and return keys for common algorithms.
  static Future<Map<String, Uint8List>> deriveKeys(String email) async {
    final Map<String, Uint8List> keys = {};

    keys['AES'] = await deriveKey(email, 256, useFirstBits: false);
    keys['ChaCha20'] = await deriveKey(email, 256, useFirstBits: false);
    keys['SM4'] = await deriveKey(email, 128, useFirstBits: false);


    return keys;
  }
}
