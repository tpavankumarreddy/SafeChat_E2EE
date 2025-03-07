import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/GroupInvitationsPage.dart';

class GroupNotifications extends StatefulWidget {
  final Function onGroupJoined; // Callback to update UI in HomePage

  const GroupNotifications({Key? key, required this.onGroupJoined}) : super(key: key);

  @override
  _GroupNotificationsState createState() => _GroupNotificationsState();
}

class _GroupNotificationsState extends State<GroupNotifications> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return Icon(Icons.notifications_none);
        }

        String uid = authSnapshot.data!.uid;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('group_announcements')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;
            if (snapshot.hasData && snapshot.data?.data() != null) {
              var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              unreadCount = data['unread_count'] ?? 0;
            }

            return _buildNotificationIcon(unreadCount);
          },
        );
      },
    );
  }

  Widget _buildNotificationIcon(int unreadCount) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(
            unreadCount > 0 ? Icons.notifications_active : Icons.notifications_none,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupInvitationsPage(
                  onGroupJoined: widget.onGroupJoined, // Pass the callback
                ),
              ),
            );
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
