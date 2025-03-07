import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'home_page.dart';
import 'join_group.dart';

class GroupInvitationsPage extends StatelessWidget {
  final Function onGroupJoined;

  GroupInvitationsPage({Key? key, required this.onGroupJoined}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    String? userEmail = FirebaseAuth.instance.currentUser?.email;

    if (uid == null || userEmail == null) return Container();

    return Scaffold(
      appBar: AppBar(title: const Text("Group Invitations")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('group_announcements').doc(uid).snapshots(),
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
                      await FirebaseFirestore.instance.collection('groups').doc(group['group_id']).get();

                      if (groupDoc.exists) {
                        var groupData = groupDoc.data();
                        if (groupData != null) {
                          // Get the group admin's email
                          String? adminEmail = groupData['admin']; // Admin is stored as email (String)

                          // Get the groupSharedSecret
                          String? encryptedGroupSecret = groupData['groupSharedSecret'];

                          // Get the shared secret key with the admin from local storage
                          String? sharedSecretKeyWithAdmin = await storage.read(key: 'shared_Secret_With_$adminEmail');

                          if (sharedSecretKeyWithAdmin != null && encryptedGroupSecret != null) {
                            // Decrypt the groupSharedSecret using shared secret key
                            String decryptedGroupSecret =
                            decryptAES(encryptedGroupSecret, sharedSecretKeyWithAdmin);
                            print("🔓 Decrypted Group Secret: $decryptedGroupSecret");
                          } else {
                            print("❌ Missing either shared secret with admin or encrypted group secret.");
                          }

                          print("👤 Group Admin: $adminEmail"); // Print the admin email
                        }
                      } else {
                        print("❌ Group document not found.");
                      }

                      // UI Update and SnackBar Notification
                      onGroupJoined();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Joined ${group['group_name']}")),
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("shared_secret_$adminEmail"); // Key format: shared_secret_<adminEmail>
  }

  /// Decrypts the given encrypted text using AES encryption with the provided key.
  String decryptAES(String encryptedText, String key) {
    final keyBytes = encrypt.Key.fromUtf8(key.padRight(32, ' ')); // Ensure 32-byte key
    final iv = encrypt.IV.fromLength(16); // Use a zero IV for simplicity (Change this for better security)
    final encrypter = encrypt.Encrypter(encrypt.AES(keyBytes, mode: encrypt.AESMode.cbc));

    try {
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      return decrypted;
    } catch (e) {
      print("❌ Decryption failed: $e");
      return "Decryption Failed";
    }
  }
}
