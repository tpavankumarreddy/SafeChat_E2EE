import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emailchat/components/chat_bubble.dart';
import 'package:emailchat/components/my_textfield.dart';
import 'package:emailchat/services/auth/auth_service.dart';
import 'package:emailchat/services/chat/chat_services.dart';
import 'package:flutter/material.dart';
import 'package:emailchat/crypto/encryption_helper.dart';
import 'package:cryptography/cryptography.dart';

class ChatPage extends StatelessWidget {
  final String receiverEmail;
  final String receiverID;
  final SecretKey secretKey;

  // Removed `const` keyword as the constructor cannot be `const`
  ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
    required this.secretKey,
  });

  // Text controller
  final TextEditingController _messageController = TextEditingController();

  // Chat & Auth services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  // Encryption helper
  final EncryptionHelper _encryptionHelper = EncryptionHelper();

  // Send Message
  Future<void> sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final encryptedData = await _encryptionHelper.encryptMessage(_messageController.text, secretKey);
      await _chatService.sendMessage(receiverID, jsonEncode({
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce']
      }));
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(receiverEmail)),
      body: Column(
        children: [
          // Display all messages
          Expanded(
            child: _buildMessageList(),
          ),
          // User input
          _buildUserInput(),
        ],
      ),
    );
  }

  // Build message list
  Widget _buildMessageList() {
    String senderID = _authService.getCurrentUser()!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(receiverID, senderID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No messages yet"));
        }
        return ListView(
          reverse: true,
          children: snapshot.data!.docs.map((doc) {
            return _buildMessageItem(doc);
          }).toList(),
        );
      },
    );
  }

  // Build message item
// Build message item
  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    if (data.isEmpty) {
      return const Text("Error loading message");
    }

    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;

    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    // Safely handle null and type casting issues
    final cipherText = data['cipherText'] as List<dynamic>? ?? [];
    final nonce = data['nonce'] as List<dynamic>? ?? [];

    if (cipherText.isEmpty || nonce.isEmpty) {
      return const Text("Error: Message content is missing");
    }

    return FutureBuilder<String>(
      future: _encryptionHelper.decryptMessage(
        List<int>.from(cipherText),
        List<int>.from(nonce),
        secretKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text("Error decrypting message: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text("Message is empty"),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
          child: Container(
            alignment: alignment,
            child: ChatBubble(
              message: snapshot.data!,
              isCurrentUser: isCurrentUser,
            ),
          ),
        );
      },
    );
  }


  // Build message input
  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Expanded(
            child: MyTextField(
              controller: _messageController,
              hintText: "Type a message",
              obscuredText: false,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            margin: const EdgeInsets.only(right: 25),
            child: IconButton(
              onPressed: sendMessage,
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
