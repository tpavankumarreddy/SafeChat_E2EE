import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

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

        // Convert bytes to hex or keep as bytes
        String decodedSecret = base64Encode(secretBytes); // If it’s a key, store it in base64

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
String generateGroupKey(List<String> sharedSecrets) {
  String concatenatedHashes = sharedSecrets
      .map((secret) => sha256.convert(utf8.encode(secret)).toString())
      .join();

  return sha256.convert(utf8.encode(concatenatedHashes)).toString();
}

String encryptGroupKey(String groupKey, String sharedSecret) {
  // Derive a 32-byte key from the shared secret
  final key = Key.fromUtf8(sha256.convert(utf8.encode(sharedSecret)).toString().substring(0, 32));

  // AES in ECB mode (no IV required)
  final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: 'PKCS7'));

  return encrypter.encrypt(groupKey).base64;
}

// Function to process group key creation and encryption
Future<Map<String, String>> createAndDistributeGroupKey(List<String> emails, String groupId) async {
  // Fetch shared secrets from secure storage
  List<String> sharedSecrets = await fetchSharedSecrets(emails);

  if (sharedSecrets.isEmpty) {
    print("No shared secrets found!");
    return {};
  }

  // Generate the group secret key
  String groupKey = generateGroupKey(sharedSecrets);
  print("Generated Group Key for Group $groupId: $groupKey");


  await storage.write(
      key: 'group_secret_key_{$groupId}',
      value: groupKey,
  );

  // Encrypt the group key for each member
  Map<String, String> encryptedKeys = {};
  for (int i = 0; i < emails.length; i++) {
    encryptedKeys[emails[i]] = encryptGroupKey(groupKey, sharedSecrets[i]);
  }

  // Display encrypted keys
  encryptedKeys.forEach((email, encryptedKey) {
    print("Encrypted key for $email: $encryptedKey");
  });

  return encryptedKeys;
}

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


