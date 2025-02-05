import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

class GroupChatPage extends StatelessWidget {
  final String groupName;
  final String groupID;
  final SecretKey secretKey;

  GroupChatPage({
    Key? key,
    required this.groupName,
    required this.groupID,
    required this.secretKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
      ),
      body: Center(
        child: Text(
          "This is the group chat page for $groupName",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}