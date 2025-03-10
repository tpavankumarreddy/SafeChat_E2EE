import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

// Initialize secure storage
final FlutterSecureStorage storage = const FlutterSecureStorage();

// Function to fetch shared secrets from secure storage
Future<List<String>> fetchSharedSecrets(List<String> emails) async {
  List<String> sharedSecrets = [];

  for (String email in emails) {
    String? encodedSecret = await storage.read(key: 'shared_Secret_With_$email');

    if (encodedSecret != null) {
      try {
        print("🔹 Found encoded secret for $email: $encodedSecret");

        // Decode base64 directly without utf8.decode()
        List<int> secretBytes = base64Decode(encodedSecret);
        String decodedSecret = base64Encode(secretBytes);

        print("✅ Decoded secret for $email: $decodedSecret");
        sharedSecrets.add(decodedSecret);
      } catch (e) {
        print("❌ Error decoding secret for $email: $e");
      }
    } else {
      print("⚠️ No shared secret found for $email");
    }
  }

  return sharedSecrets;
}

// Function to generate the group key
Future<SecretKey> generateGroupKey(List<String> sharedSecrets) async {
  List<int> concatenatedHashes = sharedSecrets
      .map((secret) => sha256.convert(utf8.encode(secret)).bytes)
      .expand((bytes) => bytes)
      .toList();

  Digest finalHash = sha256.convert(concatenatedHashes);
  return SecretKey(finalHash.bytes);
}

// Encrypt the group key
Future<String> encryptGroupKey(SecretKey groupKey, String sharedSecret) async {
  List<int> groupKeyBytes = await groupKey.extractBytes();
  final key = encrypt.Key(Uint8List.fromList(utf8.encode(sharedSecret)));
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb, padding: 'PKCS7'));
  return encrypter.encryptBytes(groupKeyBytes).base64;
}

// Create and distribute the group key
Future<Map<String, String>> createAndDistributeGroupKey(List<String> emails, String groupId) async {
  List<String> sharedSecrets = await fetchSharedSecrets(emails);

  if (sharedSecrets.isEmpty) {
    print("No shared secrets found!");
    return {};
  }

  SecretKey groupKey = await generateGroupKey(sharedSecrets);
  List<int> groupKeyBytes = await groupKey.extractBytes();
  String groupKeyBase64 = base64Encode(groupKeyBytes);
  print("Generated Group Key for Group $groupId: $groupKeyBase64");

  await storage.write(key: 'group_secret_key_$groupId', value: groupKeyBase64);

  Map<String, String> encryptedKeys = {};
  for (int i = 0; i < emails.length; i++) {
    encryptedKeys[emails[i]] = await encryptGroupKey(groupKey, sharedSecrets[i]);
  }

  encryptedKeys.forEach((email, encryptedKey) {
    print("Encrypted key for $email: $encryptedKey");
  });

  return encryptedKeys;
}

// Announce group to members
Future<void> announceGroupToMembers(String groupId, String adminEmail, String groupName, List<String> memberUids) async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  for (String uid in memberUids) {
    DocumentReference docRef = firestore.collection('group_announcements').doc(uid);

    print(memberUids);
    await firestore.runTransaction((transaction) async {
      DocumentSnapshot doc = await transaction.get(docRef);
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        List<dynamic> groups = data['groups'] ?? [];
        groups.add({
          'group_id': groupId,
          'admin': adminEmail,
          'group_name': groupName,
        });

        int unreadCount = (data['unread_count'] ?? 0) + 1;

        transaction.update(docRef, {
          'groups': groups,
          'unread_count': unreadCount,
        });
      }
    });
  }
}
