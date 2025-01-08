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

  Map<String, SecretKey> derivedKeys = {};


  late Stream<String?> _algorithmStream;
  String _selectedAlgorithm = 'AES';


  late final Stream<QuerySnapshot> _messageStream;
  List<Map<String, dynamic>> _decryptedMessages = [];

  @override
  void initState() {
    super.initState();
    _initializeDerivedKeys();

    String senderID = _authService.getCurrentUser()!.uid;
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);
    print('[ChatPage - initState] Message stream initialized for senderID: $senderID');
    //print('[ChatPage - initState] Message stream initialized for senderID: $senderID');
  }

  Future<void> _initializeDerivedKeys() async {
    try {
      final masterKeyBytes = await widget.secretKey.extractBytes();

      derivedKeys['AES'] = SecretKey(masterKeyBytes.sublist(0, 32)); // First 256 bits
      derivedKeys['ChaCha20'] = SecretKey(masterKeyBytes.sublist(0, 32)); // First 256 bits
      derivedKeys['SM4'] = SecretKey(masterKeyBytes.sublist(0, 16)); // First 128 bits
      derivedKeys['Blowfish'] = SecretKey(masterKeyBytes.sublist(0, 16)); // First 128 bits

      print('Derived keys initialized.');
    } catch (e) {
      print('Error initializing derived keys: $e');
    }
  }

  Future<void> sendMessage() async {
    print('[ChatPage - sendMessage] Line 17: sendMessage called with message: ${_messageController.text}');
    //print('[ChatPage - sendMessage] Line 17: sendMessage called with message: ${_messageController.text}');

    if (_messageController.text.isNotEmpty) {
      final encryptedData = await _encryptionHelper.encryptMessage(_messageController.text, derivedKeys[_selectedAlgorithm]!,algorithm: _selectedAlgorithm,);
      print('[ChatPage - sendMessage] Line 20: Encrypted data: $encryptedData');
      //print('[ChatPage - sendMessage] Line 20: Encrypted data: $encryptedData');


      Map<String, String> messageData = {
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce'],
      };
      await _chatService.sendMessage(
        widget.receiverID,
        jsonEncode(messageData), // Store as JSON string
        _selectedAlgorithm,
      );
      _messageController.clear();
      print('[ChatPage - sendMessage] Line 22: Message sent successfully and controller cleared');
      //print('[ChatPage - sendMessage] Line 22: Message sent successfully and controller cleared');
    }
  }

  Future<void> _decryptMessages(List<DocumentSnapshot> docs) async {
    List<Map<String, dynamic>> decryptedMessages = [];

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
      if (data.isEmpty) continue;

      final String algorithm = data['algorithm'] ?? 'AES'; // Default to 'AES' if no algorithm

      final messageJson = data['message'];
      Map<String, dynamic> messageData;
      try {
        messageData = jsonDecode(messageJson);
      } catch (e) {
        print("Error decoding message content: $e");
        //print("Error decoding message content: $e");
        continue;
      }

      final cipherTextBase64 = messageData['cipherText'] ?? '';
      final nonceBase64 = messageData['nonce'] ?? '';
      final SecretKey? key = derivedKeys[algorithm];

      // if (messageData['algorithm']=='Blowfish'){
      //   continue;
      // }
      // if (cipherTextBase64.isEmpty || nonceBase64.isEmpty) {
      //   print("Error: Message content is missing?");
      //   //print("Error: Message content is missing");
      //   continue;
      // }


      try {
        final decryptedMessage = await _encryptionHelper.decryptMessage(cipherTextBase64, nonceBase64, key!, algorithm: algorithm);
        decryptedMessages.add({
          'message': decryptedMessage,
          'isCurrentUser': data['senderID'] == _authService.getCurrentUser()!.uid,
        });
      } catch (e) {
        print("Error decrypting message: $e");
        //print("Error decrypting message: $e");
      }
    }

    setState(() {
      _decryptedMessages = decryptedMessages;
    });
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
                value: "AES",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("ChaCha20-256"),
                value: "ChaCha20",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("sm4-128"),
                value: "SM4",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("blowfish-256"),
                value: "Blowfish",
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
        //print('[ChatPage - _buildMessageList] StreamBuilder triggered');

        if (snapshot.hasError) {
         // print('[ChatPage - _buildMessageList] Error: ${snapshot.error}');
          //print('[ChatPage - _buildMessageList] Error: ${snapshot.error}');
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          //print('[ChatPage - _buildMessageList] Waiting for data...');
          //print('[ChatPage - _buildMessageList] Waiting for data...');
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
          //print('[ChatPage - _buildMessageList] No messages');
          //print('[ChatPage - _buildMessageList] No messages');
          return Center(child: Text("No messages yet"));
        }

      //  print('[ChatPage - _buildMessageList] Messages count: ${snapshot.data!.docs.length}');
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
  void _onAlgorithmSelected(String algorithm) async {
    setState(() {
      _selectedAlgorithm = algorithm;
    });

    // Notify the receiver of the algorithm change
    final algorithmChangeMessage = "Encryption algorithm changed to $_selectedAlgorithm";

    try {
      // Use the correct key for the selected algorithm
      final selectedKey = derivedKeys[_selectedAlgorithm];
      if (selectedKey == null) {
        throw Exception("No derived key found for algorithm $_selectedAlgorithm.");
      }

      final encryptedData = await _encryptionHelper.encryptMessage(
        algorithmChangeMessage,
        selectedKey,
        algorithm: _selectedAlgorithm,
      );

      await _chatService.sendMessage(
        widget.receiverID,
        jsonEncode({
          'cipherText': encryptedData['cipherText'],
          'nonce': encryptedData['nonce'],
          'isAlgorithmChange': true, // Flag for formatting
        }),
        _selectedAlgorithm,
      );

      print("Algorithm change message sent successfully.");
    } catch (e) {
      _showError("Failed to send algorithm change message: $e");
    }
  }


  void _showError(String message) {
    print(message);
  }
  Widget _buildMessageItem(Map<String, dynamic> message) {
    final bool isCurrentUser = message['isCurrentUser'];
    final String decryptedMessage = message['message'] as String;
    final bool isAlgorithmChange = message['isAlgorithmChange'] ?? false;

    // Define bubble colors for different cases
    final bubbleColor = isAlgorithmChange
        ? Colors.orangeAccent // Algorithm change messages
        : (isCurrentUser ? Colors.green : Colors.blue.shade300); // Normal chats

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ChatBubble(
        message: decryptedMessage,
        isCurrentUser: isCurrentUser,
        bubbleColor: bubbleColor,
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
              obscuredText: false, onChanged: (String ) {  },
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: sendMessage,
          ),
          IconButton(
            icon: Icon(Icons.settings), // You can change the icon if needed
            onPressed: () => _showAlgorithmSelection(context),
            tooltip: "Change Algorithm",
          ),
        ],
      ),
    );
  }
}

