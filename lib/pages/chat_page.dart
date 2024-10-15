import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/services/chat/chat_services.dart';
import 'package:SafeChat/crypto/Encryption_helper.dart';
import 'package:cryptography/cryptography.dart';
import 'package:SafeChat/components/chat_bubble.dart';
import 'package:SafeChat/components/my_textfield.dart';

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
  String _selectedAlgorithm = 'AES'; // Default encryption algorithm

  @override
  void initState() {
    super.initState();
    String senderID = _authService.getCurrentUser()!.uid;
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
  }

  Future<void> sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      final encryptedData = await _encryptionHelper.encryptMessage(
        _messageController.text,
        widget.secretKey,
        algorithm: _selectedAlgorithm, // Use the selected algorithm
      );

      await _chatService.sendMessage(widget.receiverID, jsonEncode({
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce'],
      }));
      _messageController.clear();
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
        continue;
      }

      final cipherTextBase64 = messageData['cipherText'] ?? '';
      final nonceBase64 = messageData['nonce'] ?? '';

      if (cipherTextBase64.isEmpty || nonceBase64.isEmpty) {
        continue;
      }

      try {
        final decryptedMessage = await _encryptionHelper.decryptMessage(
          cipherTextBase64,
          nonceBase64,
          widget.secretKey,
          algorithm: _selectedAlgorithm, // Use the selected algorithm
        );
        decryptedMessages.add({
          'message': decryptedMessage,
          'isCurrentUser': data['senderID'] == _authService.getCurrentUser()!.uid,
        });
      } catch (e) {
        // Handle decryption error
      }
    }

    setState(() {
      _decryptedMessages = decryptedMessages;
    });
  }

  void _onAlgorithmSelected(String algorithm) {
    setState(() {
      _selectedAlgorithm = algorithm;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverEmail),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'select_algorithm') {
                _showAlgorithmSelection(context); // Show algorithm selection
              } else if (value == 'option_2') {
                // Handle Option 2
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'select_algorithm',
                  child: Text('Select Algorithm'),
                ),
                PopupMenuItem(
                  value: 'option_2',
                  child: Text('Option 2'),
                ),
                // Add more general options if needed
              ];
            },
            icon: Icon(Icons.more_vert), // Three dots icon
          ),
        ],
      ),
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

  // Method to show algorithm selection dialog
  void _showAlgorithmSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Encryption Algorithm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('AES'),
                leading: Radio<String>(
                  value: 'AES',
                  groupValue: _selectedAlgorithm,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedAlgorithm = value!;
                    });
                    Navigator.of(context).pop(); // Close dialog
                  },
                ),
              ),
              ListTile(
                title: Text('ChaCha20'),
                leading: Radio<String>(
                  value: 'ChaCha20',
                  groupValue: _selectedAlgorithm,
                  onChanged: (String? value) {
                    setState(() {
                      _selectedAlgorithm = value!;
                    });
                    Navigator.of(context).pop(); // Close dialog
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messageStream,
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
      ),
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
