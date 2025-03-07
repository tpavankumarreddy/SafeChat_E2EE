import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'join_group.dart';

class GroupInvitationsPage extends StatelessWidget {
  final Function onGroupJoined;

  GroupInvitationsPage({Key? key, required this.onGroupJoined}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Container();

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
                      await joinGroup(group['group_id'], uid);
                      onGroupJoined(); // Trigger UI update
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
}
