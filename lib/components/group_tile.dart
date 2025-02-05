import 'package:flutter/material.dart';

class GroupTile extends StatelessWidget {
  final String groupName;
  final String members;
  final VoidCallback onTap;

  const GroupTile({
    Key? key,
    required this.groupName,
    required this.members,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(groupName),
      subtitle: Text('Members: $members'),
      leading: Icon(Icons.group),
      onTap: onTap,
    );
  }
}