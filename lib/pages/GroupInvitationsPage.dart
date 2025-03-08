import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'home_page.dart';
import 'join_group.dart';
import 'package:crypto/crypto.dart';

class GroupInvitationsPage extends StatelessWidget {
  final Function onGroupJoined;

  GroupInvitationsPage({Key? key, required this.onGroupJoined})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    String? userEmail = FirebaseAuth.instance.currentUser?.email;

    if (uid == null || userEmail == null) return Container();

    return Scaffold(
      appBar: AppBar(title: const Text("Group Invitations")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('group_announcements')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          List<dynamic> groups = data['groups'] ?? [];

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              var group = groups[index];
              return ListTile(
                title: Text(group['group_name']),
                subtitle: Text("Admin: ${group['admin']}"),
                trailing: ElevatedButton(
                  onPressed: () async {
                    try {
                      // Call joinGroup function
                      await joinGroup(group['group_id'], uid);

                      // Retrieve the group document from Firestore
                      DocumentSnapshot<Map<String, dynamic>> groupDoc =
                      await FirebaseFirestore.instance.collection('groups').doc(
                          group['group_id']).get();

                      if (groupDoc.exists) {
                        var groupData = groupDoc.data();
                        if (groupData != null) {
                          // Get the group admin's email
                          String? adminEmail = groupData['admin']; // Admin stored as email (String)

                          String? groupId = groupData['group_id'];
                          // Get the groupSecretKeys map from Firestore
                          Map<String,
                              dynamic>? groupSecretKeys = groupData['groupSecretKeys'];

                          if (groupSecretKeys != null && adminEmail != null) {
                            // Find the encrypted group secret for this admin
                            String? encryptedGroupSecret = groupSecretKeys[userEmail];

                            // Get the shared secret key with the admin from local storage
                            String? sharedSecretKeyWithAdmin = await getSharedSecretWithAdmin(
                                adminEmail);

                            print(adminEmail);
                            print(sharedSecretKeyWithAdmin);
                            print(encryptedGroupSecret);
                            if (sharedSecretKeyWithAdmin != null &&
                                encryptedGroupSecret != null) {
                              // Decrypt the groupSharedSecret using shared secret key
                              String? decryptedGroupSecret = await decryptGroupKey(
                                  encryptedGroupSecret,
                                  adminEmail);
                              print(
                                  "🔓 Decrypted Group Secret: $decryptedGroupSecret");
                              await storage.write(
                                key: 'group_secret_key_{$groupId}',
                                value: decryptedGroupSecret,
                              );
                            } else {
                              print(
                                  "❌ Missing either shared secret with admin or encrypted group secret.");
                            }
                          }


                          print(
                              "👤 Group Admin: $adminEmail"); // Print the admin email
                        }
                      } else {
                        print("❌ Group document not found.");
                      }

                      // UI Update and SnackBar Notification
                      onGroupJoined();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                            "Joined ${group['group_name']}")),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to join: $e")),
                      );
                    }
                  },
                  child: const Text("Join"),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Retrieves the shared secret key with the given admin email from local storage.
  Future<String?> getSharedSecretWithAdmin(String adminEmail) async {
    return await storage.read(
      key: 'shared_Secret_With_$adminEmail',
    );
  }

  String decryptGroupKey(String encryptedGroupKey, String sharedSecret) {
    try {
      final key = encrypt.Key.fromUtf8(sha256.convert(utf8.encode(sharedSecret)).toString().substring(0, 32));

      // AES in ECB mode (no IV required)
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));

      return encrypter.decrypt64(encryptedGroupKey);
    } catch (e) {
      print("❌ Decryption failed: $e");
      return "Decryption Failed";
    }
  }
}