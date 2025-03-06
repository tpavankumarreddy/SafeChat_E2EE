import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';
import 'home_page.dart';

final storage = FlutterSecureStorage();

Future<void> joinGroup(String groupId) async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Fetch the group details from Firestore
    DocumentSnapshot<Map<String, dynamic>> groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();

    if (groupDoc.exists) {
      String groupName = groupDoc.data()?['groupName'] ?? 'Unknown Group';
      List<String> members = List<String>.from(groupDoc.data()?['groupMembers'] ?? []);

      // Save group details in the local database
      await DatabaseHelper.instance.insertGroup(groupName, members);

      print("✅ Group added to local DB: $groupName");

      // Reload groups in UI
      HomePageState _h = HomePageState();
      _h.loadGroupChats();
    } else {
      print("❌ Group not found.");
    }

  }catch(e){
    print(e);
  }
  }
