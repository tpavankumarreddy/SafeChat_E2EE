import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

import '../data/database_helper.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;

  GroupDetailsPage({required this.groupId});

  @override
  _GroupDetailsPageState createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  Map<String, dynamic>? groupData;
  List<Map<String, dynamic>> members = [];
  String? adminName;
  String? adminId;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
    fetchGroupDetails();
  }

  void getCurrentUser() {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      currentUserId = user?.email;
    });
  }

  Future<void> fetchGroupDetails() async {
    try {
      var groupSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (groupSnapshot.exists) {
        setState(() {
          groupData = groupSnapshot.data();
          adminId = groupData!['admin']; // Assuming 'admin' stores the UID
        });

        fetchGroupMembers();
      }
    } catch (e) {
      print("Error fetching group details: $e");
    }
  }

  Future<void> fetchGroupMembers() async {
    try {
      List<String> localMembers = await DatabaseHelper.instance.fetchGroupMembersFromDB(widget.groupId);

      setState(() {
        members = localMembers.map((member) => {'email': member}).toList();
      });

      print("✅ Group members fetched from local DB: $members");
    } catch (e) {
      print("❌ Error fetching members: $e");
    }
  }

  void inviteMember() {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Invite Member"),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(hintText: "Enter email"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String email = emailController.text.trim();
                if (email.isNotEmpty) {
                  await sendInvitation(email);
                }
                Navigator.pop(context);
              },
              child: Text("Send Invite"),
            ),
          ],
        );
      },
    );
  }

  Future<void> sendInvitation(String email) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Fetch user UID based on email
      QuerySnapshot userSnapshot = await firestore
          .collection("user's")
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User with email $email not found!")),
        );
        return;
      }

      String userId = userSnapshot.docs.first.id;

      DocumentReference docRef =
      firestore.collection('group_announcements').doc(userId);

      await firestore.runTransaction((transaction) async {
        DocumentSnapshot doc = await transaction.get(docRef);

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          List<dynamic> groups = data['groups'] ?? [];
          groups.add({
            'group_id': widget.groupId,
            'admin': FirebaseAuth.instance.currentUser?.email ?? "Unknown",
            'group_name': groupData!['name'],
          });

          int unreadCount = (data['unread_count'] ?? 0) + 1;

          transaction.update(docRef, {
            'groups': groups,
            'unread_count': unreadCount,
          });
        } else {
          transaction.set(docRef, {
            'groups': [
              {
                'group_id': widget.groupId,
                'admin': FirebaseAuth.instance.currentUser?.email ?? "Unknown",
                'group_name': groupData!['name'],
              }
            ],
            'unread_count': 1,
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invitation sent to $email")),
      );
    } catch (e) {
      print("Error sending invitation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Group Details")),
      body: groupData == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Group Name: ${groupData!['groupName']}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

            SizedBox(height: 10),
            Text("Group Description: ${groupData!['description'] ?? 'No description'}"),
            SizedBox(height: 20),
            Text("Admin: ${groupData!['admin']}",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            SizedBox(height: 20),
            Text("Members:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      (members[index].containsKey('email'))
                          ? members[index]['email'] ?? "Unknown Name"  // Fallback if 'name' is null
                          : "Unknown Member", // Fallback if structure is incorrect
                    ),
                  );

                },
              ),
            ),
            if (currentUserId == adminId) // Show button only for admin
              Center(
                child: ElevatedButton(
                  onPressed: inviteMember,
                  child: Text("Invite Member"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
