import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:SafeChat/components/chat_bubble.dart';
import 'package:SafeChat/components/my_textfield.dart';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/services/chat/chat_services.dart';
import 'package:flutter/material.dart';
import 'package:SafeChat/crypto/Encryption_helper.dart';
import 'package:cryptography/cryptography.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;
  final SecretKey secretKey;

  ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
    required this.secretKey,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final EncryptionHelper _encryptionHelper = EncryptionHelper();

  late final Stream<QuerySnapshot> _messageStream;

  @override
  void initState() {
    super.initState();
    String senderID = _authService.getCurrentUser()!.uid;
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
  }

  Future<void> sendMessage() async {
    print('[ChatPage - sendMessage] Line 17: sendMessage called with message: ${_messageController.text}');

    if (_messageController.text.isNotEmpty) {
      final encryptedData = await _encryptionHelper.encryptMessage(_messageController.text, widget.secretKey);
      print('[ChatPage - sendMessage] Line 20: Encrypted data: $encryptedData');

      await _chatService.sendMessage(widget.receiverID, jsonEncode({
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce'],
      }));
      _messageController.clear();
      print('[ChatPage - sendMessage] Line 22: Message sent successfully and controller cleared');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverEmail)),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messageStream,
      builder: (context, snapshot) {
        print('[ChatPage - _buildMessageList] StreamBuilder triggered');

        // Print snapshot information for debugging
        print('[ChatPage - _buildMessageList] Connection State: ${snapshot.connectionState}');
        print('[ChatPage - _buildMessageList] Snapshot has Error: ${snapshot.hasError}');
        print('[ChatPage - _buildMessageList] Snapshot Data: ${snapshot.data}');
        print('[ChatPage - _buildMessageList] Snapshot Data Docs: ${snapshot.data?.docs}');

        if (snapshot.hasError) {
          print('[ChatPage - _buildMessageList] Error: ${snapshot.error}');
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[ChatPage - _buildMessageList] Waiting for data...');
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
          print('[ChatPage - _buildMessageList] No messages');
          return Center(child: Text("No messages yet"));
        }

        print('[ChatPage - _buildMessageList] Messages count: ${snapshot.data!.docs.length}');

        return ListView(
          reverse: true,
          children: snapshot.data!.docs.map((doc) {
            print('[ChatPage - _buildMessageList] Document data: ${doc.data()}');
            return _buildMessageItem(doc);
          }).toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};

    print('[ChatPage - _buildMessageItem] Line 64: Message data for decryption: $data');

    if (data.isEmpty) {
      print('[ChatPage - _buildMessageItem] No data found');
      return const Text("Error loading message");
    }

    bool isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;
    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    final messageJson = data['message'];
    Map<String, dynamic> messageData;
    try {
      messageData = jsonDecode(messageJson);
      print('[ChatPage - _buildMessageItem] Message data JSON: $messageData');
    } catch (e) {
      print('[ChatPage - _buildMessageItem] Error decoding message JSON: $e');
      return const Text("Error decoding message content");
    }

    final cipherTextBase64 = messageData['cipherText'] ?? '';
    final nonceBase64 = messageData['nonce'] ?? '';

    print('[ChatPage - _buildMessageItem] Cipher Text Base64: $cipherTextBase64');
    print('[ChatPage - _buildMessageItem] Nonce Base64: $nonceBase64');

    if (cipherTextBase64.isEmpty || nonceBase64.isEmpty) {
      print('[ChatPage - _buildMessageItem] Error: Message content is missing');
      return const Text("Error: Message content is missing");
    }

    return FutureBuilder<String>(
      future: _encryptionHelper.decryptMessage(
        cipherTextBase64,
        nonceBase64,
        widget.secretKey,
      ),
      builder: (context, snapshot) {
        print('[ChatPage - _buildMessageItem] FutureBuilder triggered');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('[ChatPage - _buildMessageItem] Waiting for decryption...');
          return const Padding(
            padding: EdgeInsets.all(5.0),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          print('[ChatPage - _buildMessageItem] Error decrypting message: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text("Error decrypting message: ${snapshot.error}"),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          print('[ChatPage - _buildMessageItem] Decrypted message is null or empty');
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Text("Message is empty"),
          );
        }

        print('[ChatPage - _buildMessageItem] Decrypted message: ${snapshot.data}');

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


  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Expanded(
            child: MyTextField(
              controller: _messageController,
              hintText: 'Type a message',
              obscuredText: false,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: sendMessage,
          ),
        ],
      ),
    );
  }
}

