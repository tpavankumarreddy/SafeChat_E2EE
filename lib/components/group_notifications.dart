import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/GroupInvitationsPage.dart';

class GroupNotifications extends StatefulWidget {
  @override
  _GroupNotificationsState createState() => _GroupNotificationsState();
}

class _GroupNotificationsState extends State<GroupNotifications> {
  String? uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (uid == null) return Container();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('group_announcements').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Icon(Icons.notifications);
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        int unreadCount = data['unread_count'] ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GroupInvitationsPage()),
                );
              },
            ),

            if (unreadCount > 0)
              Positioned(
                right: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    unreadCount.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
