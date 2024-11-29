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
  late final Stream<List<Map<String, dynamic>>> _notificationStream;
  List<Map<String, dynamic>> _decryptedMessages = [];
  String _selectedAlgorithm = 'AES-256'; // Default encryption algorithm

  @override
  void initState() {
    super.initState();
    String senderID = _authService.getCurrentUser()!.uid;
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
    _notificationStream = _getAlgorithmChangeNotificationsStream(senderID);
  }

  Stream<List<Map<String, dynamic>>> _getAlgorithmChangeNotificationsStream(
      String currentUserID) {
    List<String> ids = [_authService.getCurrentUser()!.uid, widget.receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _chatService
        .getAlgorithmChangeNotifications(chatRoomID, currentUserID);
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

      final String algorithm = data['algorithm'] ?? _selectedAlgorithm; // Default to 'AES' if no algorithm
      final String messageJson = data['message'] ?? '';

      if (messageJson.isEmpty) {
        print("Received empty message JSON");
        continue;
      }

      if (algorithm != _selectedAlgorithm) {
        _showError(
          'Algorithm mismatch! Both users need to use the same encryption algorithm to chat.',
        );
        continue;
      }

      Map<String, dynamic> messageData;
      try {
        messageData = jsonDecode(messageJson);
      } catch (e) {
        print("Error parsing message JSON: $e");
        continue;
      }

      final String cipherTextBase64 = messageData['cipherText'] ?? '';
      final String nonceBase64 = messageData['nonce'] ?? '';

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

    _notifyRecipientAboutAlgorithmChange(algorithm);
  }

  void _notifyRecipientAboutAlgorithmChange(String algorithm) {
    _chatService.notifyAlgorithmChange(widget.receiverID, algorithm).then((_) {
      setState(() {});
    }).catchError((e) {
      print("Error notifying recipient about algorithm change: $e");
    });
  }

  void _respondToAlgorithmChange(String notificationID, bool isAccepted) async {
    List<String> ids = [_authService.getCurrentUser()!.uid, widget.receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    await _chatService
        .respondToAlgorithmChange(chatRoomID, notificationID, isAccepted)
        .then((_) {
      final message = isAccepted
          ? 'Algorithm change accepted. Continuing with the new algorithm.'
          : 'Algorithm change declined. Continuing with the previous algorithm.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      if (isAccepted) {
        setState(() {
          _selectedAlgorithm = 'newAlgorithm'; // Replace with the actual new algorithm
        });
      }
    }).catchError((e) {
      print("Error responding to algorithm change: $e");
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
                _showAlgorithmSelection(context);
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
            icon: Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildMessageList(),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _notificationStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SizedBox();
                    }

                    final notifications = snapshot.data!;
                    return Column(
                      children: notifications.map((notification) {
                        return AlertDialog(
                          title: Text('Algorithm Change Request'),
                          content: Text(
                              'The other user has requested to change the encryption algorithm to "${notification['newAlgorithm']}". Do you accept?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                _respondToAlgorithmChange(
                                    notification['id'], true);
                              },
                              child: Text('Accept'),
                            ),
                            TextButton(
                              onPressed: () {
                                _respondToAlgorithmChange(
                                    notification['id'], false);
                              },
                              child: Text('Decline'),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: MyTextField(
              controller: _messageController,
              hintText: "Type your message...",
              obscuredText: false, onChanged: (String ) {  },
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showAlgorithmSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Encryption Algorithm"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text("AES-256"),
                value: "AES-256",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected("AES-256");
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("ChaCha20-256"),
                value: "CHACHA20-256",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected("CHACHA20-256");
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}