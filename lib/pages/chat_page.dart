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
    Key? key,
    required this.receiverEmail,
    required this.receiverID,
    required this.secretKey,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final EncryptionHelper _encryptionHelper = EncryptionHelper();

  late Stream<QuerySnapshot> _messageStream;
  late Stream<String?> _algorithmStream;
  late Stream<List<Map<String, dynamic>>> _notificationStream;
  List<Map<String, dynamic>> _decryptedMessages = [];
  String _selectedAlgorithm = 'AES-256';

  @override
  void initState() {
    super.initState();
    String senderID = _authService.getCurrentUser()!.uid;

    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
    _algorithmStream = _chatService.getAlgorithm(senderID, widget.receiverID);
    _notificationStream = _getAlgorithmChangeNotificationsStream(senderID);

    _algorithmStream.listen((newAlgorithm) {
      if (newAlgorithm != null && newAlgorithm != _selectedAlgorithm) {
        setState(() {
          _selectedAlgorithm = newAlgorithm;
        });
      }
    });
  }

  Stream<List<Map<String, dynamic>>> _getAlgorithmChangeNotificationsStream(
      String currentUserID) {
    List<String> ids = [currentUserID, widget.receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');
    return _chatService.getAlgorithmChangeNotifications(chatRoomID, currentUserID);
  }

  Future<void> sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        final encryptedData = await _encryptionHelper.encryptMessage(
          _messageController.text,
          widget.secretKey,
          algorithm: _selectedAlgorithm,
        );

        await _chatService.sendMessage(
          widget.receiverID,
          jsonEncode(encryptedData),
          _selectedAlgorithm,
        );

        _messageController.clear();
      } catch (e) {
        _showError("Error encrypting message: $e");
      }
    }
  }

  Future<void> _decryptMessages(List<DocumentSnapshot> docs) async {
    List<Map<String, dynamic>> decryptedMessages = [];

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      final String algorithm = data['algorithm'] ?? _selectedAlgorithm;

      if (algorithm != _selectedAlgorithm) {
        _showError("Algorithm mismatch detected. Update your algorithm.");
        continue;
      }

      final String messageJson = data['message'];
      Map<String, dynamic> messageData = jsonDecode(messageJson);

      try {
        final decryptedMessage = await _encryptionHelper.decryptMessage(
          messageData['cipherText'],
          messageData['nonce'],
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

  void _respondToAlgorithmChange(String notificationID, bool isAccepted,
      String newAlgorithm) async {
    List<String> ids = [_authService.getCurrentUser()!.uid, widget.receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    await _chatService
        .respondToAlgorithmChange(chatRoomID, notificationID, isAccepted, newAlgorithm)
        .then((_) {
      if (isAccepted) {
        setState(() {
          _selectedAlgorithm = newAlgorithm;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAccepted
            ? 'Algorithm updated to $newAlgorithm'
            : 'Algorithm change declined.'),
      ));
    }).catchError((e) {
      print("Error responding to algorithm change: $e");
    });
  }

  Widget _buildNotificationList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox();

        final notifications = snapshot.data!;
        return Column(
          children: notifications.map((notification) {
            return AlertDialog(
              title: Text('Algorithm Change Request'),
              content: Text(
                  'Change encryption algorithm to "${notification['newAlgorithm']}"?'),
              actions: [
                TextButton(
                  onPressed: () {
                    _respondToAlgorithmChange(
                        notification['id'], true, notification['newAlgorithm']);
                  },
                  child: Text('Accept'),
                ),
                TextButton(
                  onPressed: () {
                    _respondToAlgorithmChange(
                        notification['id'], false, _selectedAlgorithm);
                  },
                  child: Text('Decline'),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
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
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("ChaCha20-256"),
                value: "CHACHA20-256",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("Blowfish-128"),
                value: "Blowfish-128",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("Fernet-256"),
                value: "Fernet-256",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onAlgorithmSelected(String algorithm) {
    setState(() {
      _selectedAlgorithm = algorithm;
    });

    _chatService.notifyAlgorithmChange(widget.receiverID, algorithm);
  }

  void _showError(String message) {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(message),
    //   backgroundColor: Colors.red,
    // ));
    print(message);
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
                _buildNotificationList(),
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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
              obscuredText: false,
              onChanged: (value) {},
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
}
