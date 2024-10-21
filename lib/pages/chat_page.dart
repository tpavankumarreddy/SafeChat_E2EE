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
  String _recipientAlgorithm = 'AES'; // Recipient's current algorithm

  @override
  void initState() {
    super.initState();
    String senderID = _authService.getCurrentUser()!.uid;
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
  }

  Future<void> sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        // Encrypt message with selected algorithm
        final encryptedData = await _encryptionHelper.encryptMessage(
          _messageController.text,
          widget.secretKey,
          algorithm: _selectedAlgorithm,
        );

        // Create a message structure
        Map<String, String> messageData = {
          'cipherText': encryptedData['cipherText'],
          'nonce': encryptedData['nonce'],
        };

        // Send message along with the algorithm used
        await _chatService.sendMessage(
          widget.receiverID,
          jsonEncode(messageData), // Store as JSON string
          _selectedAlgorithm,
        );

        _messageController.clear();
      } catch (e) {
        print("Error encrypting message: $e");
      }
    }
  }

  Future<void> _decryptMessages(List<DocumentSnapshot> docs) async {
    List<Map<String, dynamic>> decryptedMessages = [];

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
      if (data.isEmpty) continue;

      final String algorithm = data['algorithm'] ?? 'AES'; // Default to 'AES' if no algorithm
      final String messageJson = data['message'] ?? '';

      // Ensure message JSON is not empty
      if (messageJson.isEmpty) {
        print("Received empty message JSON");
        continue;
      }

      // If the recipient is using a different algorithm, display an error and skip decryption
      if (algorithm != _selectedAlgorithm) {
        _showError(
          'Algorithm mismatch! Both users need to use the same encryption algorithm to chat.',
        );
        continue; // Skip to the next message if algorithms do not match
      }

      Map<String, dynamic> messageData;
      try {
        messageData = jsonDecode(messageJson);
      } catch (e) {
        print("Error parsing message JSON: $e");
        continue; // Skip to the next message if parsing fails
      }

      final String cipherTextBase64 = messageData['cipherText'] ?? '';
      final String nonceBase64 = messageData['nonce'] ?? '';

      // Ensure cipherText and nonce are not empty
      if (cipherTextBase64.isEmpty || nonceBase64.isEmpty) {
        print("Received empty cipherText or nonce");
        continue;
      }

      try {
        final decryptedMessage = await _encryptionHelper.decryptMessage(
          cipherTextBase64,
          nonceBase64,
          widget.secretKey,
          algorithm: algorithm,
        );

        decryptedMessages.add({
          'message': decryptedMessage,
          'isCurrentUser': data['senderID'] == _authService.getCurrentUser()!.uid,
        });
      } catch (e) {
        print("Error decrypting message: $e");
      }
    }

    setState(() {
      _decryptedMessages = decryptedMessages.reversed.toList();
    });
  }

  void _onAlgorithmSelected(String algorithm) {
    setState(() {
      _selectedAlgorithm = algorithm;
    });

    // Notify the recipient about the algorithm change
    _notifyRecipientAboutAlgorithmChange(algorithm);
  }

  void _notifyRecipientAboutAlgorithmChange(String algorithm) {
    _chatService.notifyAlgorithmChange(widget.receiverID, algorithm).then((_) {
      setState(() {
        _recipientAlgorithm = algorithm;
      });
    }).catchError((e) {
      print("Error notifying recipient about algorithm change: $e");
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
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 'select_algorithm',
                  child: Text('Select Algorithm'),
                ),
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
                    if (value != null) {
                      _onAlgorithmSelected(value);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text('ChaCha20'),
                leading: Radio<String>(
                  value: 'ChaCha20',
                  groupValue: _selectedAlgorithm,
                  onChanged: (String? value) {
                    if (value != null) {
                      _onAlgorithmSelected(value);
                    }
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

        // Decrypt messages
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
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: MyTextField(
              controller: _messageController,
              hintText: "Type your message...",
              obscuredText: false, // If you want to show the text, keep it false
              onChanged: (value) {
                // Handle the text changes here, if needed.
                print("Text changed: $value");
              },
            ),
          ),
          IconButton(
            onPressed: sendMessage,
            icon: Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  // Display error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
