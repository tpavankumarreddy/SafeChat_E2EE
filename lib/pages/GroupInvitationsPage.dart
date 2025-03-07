import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'join_group.dart';

class GroupInvitationsPage extends StatelessWidget {
  final Function onGroupJoined;

  GroupInvitationsPage({required this.onGroupJoined});
  @override
  Widget build(BuildContext context) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Container();

    return Scaffold(
      appBar: AppBar(title: Text("Group Invitations")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('group_announcements')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
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
                    await joinGroup(group['group_id'],onGroupJoined);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Joined ${group['group_name']}"))
                    );
                  },
                  child: Text("Join"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
