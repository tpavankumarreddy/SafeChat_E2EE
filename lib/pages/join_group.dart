import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';
import 'home_page.dart';

final storage = FlutterSecureStorage();
/// Function to handle joining a group
Future<void> joinGroup(String groupId, String userId) async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  DocumentReference groupRef = firestore.collection('groups').doc(groupId);
  DocumentReference userRef = firestore.collection("user's").doc(userId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    // Add the user to the group's members list
    transaction.update(groupRef, {
      'members': FieldValue.arrayUnion([userId]),
    });

    // Add the group to the user's joined groups
    transaction.update(userRef, {
      'joined_groups': FieldValue.arrayUnion([groupId]),
    });

    // Remove the invitation from `group_announcements`
    transaction.update(firestore.collection('group_announcements').doc(userId), {
      'groups': FieldValue.arrayRemove([
        {'group_id': groupId, 'group_name': groupRef.id, 'admin': 'admin_name'}
      ]),
    });
  });
}
