import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final String? sender; // Nullable sender field
  final bool isCurrentUser;
  final Color bubbleColor;

  const ChatBubble({
    super.key,
    required this.message,
    this.sender, // Nullable sender
    required this.isCurrentUser,
    this.bubbleColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isCurrentUser ? 12 : 0),
            topRight: Radius.circular(isCurrentUser ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
        ),
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sender != null && sender!.isNotEmpty) // Conditionally show sender
              Padding(
                padding: const EdgeInsets.only(bottom: 4), // Small spacing
                child: Text(
                  sender!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            Text(
              message,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
