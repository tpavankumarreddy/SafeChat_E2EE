import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final Color bubbleColor;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.bubbleColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor, // Use the dynamic color
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isCurrentUser ? 12 : 0), // Rounded for sent messages
            topRight: Radius.circular(isCurrentUser ? 0 : 12), // Rounded for received messages
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Text(
          message,
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black, // Text color based on sender
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
