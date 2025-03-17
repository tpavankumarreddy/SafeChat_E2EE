import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    fetchGroupDetails();
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
          adminName = groupData!['admin']; // Assuming 'admin' stores the name or ID
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
            Text("Admin: $adminName", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
          ],
        ),
      ),
    );
  }
}
