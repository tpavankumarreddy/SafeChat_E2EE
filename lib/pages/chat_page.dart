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
  List<Map<String, dynamic>> _decryptedMessages = [];

  @override
  void initState() {
    super.initState();
    String senderID = _authService.getCurrentUser()!.uid;
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
    //print('[ChatPage - initState] Message stream initialized for senderID: $senderID');
  }

  Future<void> sendMessage() async {
    //print('[ChatPage - sendMessage] Line 17: sendMessage called with message: ${_messageController.text}');

    if (_messageController.text.isNotEmpty) {
      final encryptedData = await _encryptionHelper.encryptMessage(_messageController.text, widget.secretKey);
      //print('[ChatPage - sendMessage] Line 20: Encrypted data: $encryptedData');

      await _chatService.sendMessage(widget.receiverID, jsonEncode({
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce'],
      }));
      _messageController.clear();
      //print('[ChatPage - sendMessage] Line 22: Message sent successfully and controller cleared');
    }
  }

  Future<void> _decryptMessages(List<DocumentSnapshot> docs) async {
    List<Map<String, dynamic>> decryptedMessages = [];

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
      if (data.isEmpty) continue;

      final messageJson = data['message'];
      Map<String, dynamic> messageData;
      try {
        messageData = jsonDecode(messageJson);
      } catch (e) {
        //print("Error decoding message content: $e");
        continue;
      }

      final cipherTextBase64 = messageData['cipherText'] ?? '';
      final nonceBase64 = messageData['nonce'] ?? '';

      if (cipherTextBase64.isEmpty || nonceBase64.isEmpty) {
        //print("Error: Message content is missing");
        continue;
      }

      try {
        final decryptedMessage = await _encryptionHelper.decryptMessage(cipherTextBase64, nonceBase64, widget.secretKey);
        decryptedMessages.add({
          'message': decryptedMessage,
          'isCurrentUser': data['senderID'] == _authService.getCurrentUser()!.uid,
        });
      } catch (e) {
        //print("Error decrypting message: $e");
      }
    }

    setState(() {
      _decryptedMessages = decryptedMessages;
    });
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
        //print('[ChatPage - _buildMessageList] StreamBuilder triggered');

        if (snapshot.hasError) {
          //print('[ChatPage - _buildMessageList] Error: ${snapshot.error}');
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          //print('[ChatPage - _buildMessageList] Waiting for data...');
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
          //print('[ChatPage - _buildMessageList] No messages');
          return Center(child: Text("No messages yet"));
        }

        //print('[ChatPage - _buildMessageList] Messages count: ${snapshot.data!.docs.length}');

        // Decrypt messages and update the state
        _decryptMessages(snapshot.data!.docs);

        return ListView(
          reverse: true,
          children: _decryptedMessages.map((msg) {
            return _buildMessageItem(msg);
          }).toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    bool isCurrentUser = message['isCurrentUser'];
    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final decryptedMessage = message['message'] as String;

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
    child: Container(
    alignment: alignment,
    child: ChatBubble(
    message: decryptedMessage,
    isCurrentUser: isCurrentUser,
    ),
    ));
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
              obscuredText: false, onChanged: (value) {  },
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
