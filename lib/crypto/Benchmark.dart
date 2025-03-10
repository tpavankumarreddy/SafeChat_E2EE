import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:SafeChat/crypto/Encryption_helper.dart';

void main() async {
  final encryptionHelper = EncryptionHelper();
  final message = "Benchmark test message";
  final random = Random.secure();

  // Function to generate a random key of specified length
  Uint8List generateKey(int length) {
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  // List of encryption algorithms with required key lengths
  final algorithms = {
    'AES': 32, // 256-bit key
    'ChaCha20': 32, // 256-bit key
    'SM4': 16, // 128-bit key
    'Blowfish': 16, // 128-bit key
  };

  for (var entry in algorithms.entries) {
    final algorithm = entry.key;
    final keyLength = entry.value;
    final secretKey = SecretKey(generateKey(keyLength));

    print("Benchmarking $algorithm...");

    // Measure encryption time
    final stopwatch = Stopwatch()..start();
    final encrypted = await encryptionHelper.encryptMessage(
      message,
      secretKey,
      algorithm: algorithm,
    );
    stopwatch.stop();
    print("$algorithm Encryption Time: ${stopwatch.elapsedMicroseconds} μs");

    // Measure decryption time
    final cipherText = encrypted['cipherText'];
    final nonce = encrypted['nonce'];

    stopwatch
      ..reset()
      ..start();
    final decrypted = await encryptionHelper.decryptMessage(
      cipherText,
      nonce,
      secretKey,
      algorithm: algorithm,
    );
    stopwatch.stop();
    print("$algorithm Decryption Time: ${stopwatch.elapsedMicroseconds} μs");

    // Validate correctness
    if (decrypted == message) {
      print("$algorithm Decryption Successful ✅\n");
    } else {
      print("$algorithm Decryption Failed ❌\n");
    }
  }
}
