import 'package:flutter/material.dart';

class GroupTile extends StatelessWidget {
  final String groupName;
  final VoidCallback onTap;

  const GroupTile({
    Key? key,
    required this.groupName,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(groupName),
      leading: Icon(Icons.group),
      onTap: onTap,
    );
  }
}