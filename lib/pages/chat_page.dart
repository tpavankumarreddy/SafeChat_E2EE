import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:SafeChat/components/chat_bubble.dart';
import 'package:SafeChat/components/my_textfield.dart';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/services/chat/chat_services.dart';
import 'package:flutter/material.dart';
import 'package:SafeChat/crypto/Encryption_helper.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import '../data/database_helper.dart';

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

  // Disappearing messages feature
  bool _isDisappearingMessagesEnabled = false;
  Duration _disappearingDuration = Duration(seconds: 10); // Default duration
  bool _isClockButtonVisible = false;
  Set<String> _selectedMessageIds = {}; // Track selected messages
  bool _isSelectionMode = false;


  @override
  void initState() {
    super.initState();
    _initializeDerivedKeys();
    //_secureFlag();
    String senderID = _authService.getCurrentUser()!.uid;

    // Initialize message stream only once
    _messageStream = _chatService.getMessages(widget.receiverID, senderID);

    // Sync messages to local DB
    _chatService.syncMessagesToLocalDB(senderID, widget.receiverID);

    // Listen for new messages and decrypt
    _messageStream.listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        print("[ChatPage] New messages received");
        await _decryptMessages(snapshot.docs);

        // Check if the widget is still mounted before updating the UI
        if (mounted) {
          setState(() {}); // Update UI after decrypting messages
        }
      }
    });

    print('[ChatPage - initState] Message stream initialized for senderID: $senderID');
  }
  Future<void> _secureFlag() async {
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }
  //
  // @override
  // void dispose() {
  //   _messageController.dispose();
  //   super.dispose();
  // }

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
    if (_messageController.text.isNotEmpty) {
      // Encrypt the message
      final encryptedData = await _encryptionHelper.encryptMessage(
        _messageController.text,
        derivedKeys[_selectedAlgorithm]!,
        algorithm: _selectedAlgorithm,
      );

      print("[sendMessage] Encrypted message: $encryptedData");

      // Prepare message data
      Map<String, String> messageData = {
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce'],
      };

      // Add the message to Firestore
      String? messageId = await _chatService.sendMessage(
        widget.receiverID,
        jsonEncode(messageData),
        _selectedAlgorithm,
      );

      print("[sendMessage] Message added to Firestore with ID: $messageId");

      // If disappearing messages is enabled, schedule deletion
      if (_isDisappearingMessagesEnabled) {
        _scheduleMessageDeletion(messageId!);
      }

      // Clear the message input
      _messageController.clear();
    }
  }

  Set<String> processedMessageIds = {}; // Track processed message IDs

  Future _decryptMessages(List docs) async {
    if (!mounted) return;

    for (var doc in docs) {
      String messageId = doc.id;

      // Skip if already processed
      if (processedMessageIds.contains(messageId)) continue;

      Map data = doc.data() as Map? ?? {};
      if (data.isEmpty) continue;

      final String algorithm = data['algorithm'] ?? 'AES'; // Default to AES
      final messageJson = data['message'];

      try {
        Map messageData = jsonDecode(messageJson);
        final cipherTextBase64 = messageData['cipherText'] ?? '';
        final nonceBase64 = messageData['nonce'] ?? '';
        final SecretKey? key = derivedKeys[algorithm];

        if (cipherTextBase64.isEmpty || nonceBase64.isEmpty || key == null) {
          continue; // Skip if missing necessary data
        }

        final decryptedMessage = await _encryptionHelper.decryptMessage(
          cipherTextBase64,
          nonceBase64,
          key,
          algorithm: algorithm,
        );

        // Prepare the decrypted message to be added to the list
        _decryptedMessages.insert(0, {
          'message': decryptedMessage,
          'messageId': messageId, // Store the message ID
          'isCurrentUser': data['senderID'] == _authService.getCurrentUser()!.uid,
          'isAlgorithmChange': messageData['isAlgorithmChange'] ?? false,
        });

        // Mark this message as processed
        processedMessageIds.add(messageId);
      } catch (e) {
        print("Error decrypting message: $e");
      }
    }

    // Update the UI
    if (mounted) {
      setState(() {});
    }
  }

  final Set<Future<void>> _pendingDeletionTasks = {};

  void _scheduleMessageDeletion(String messageId) async {
    try {
      String? senderID = _authService.getCurrentUser()?.uid;
      if (senderID == null) return;

      final deletionTask = Future.delayed(_disappearingDuration).then((_) async {
        if (!mounted) return;

        await _chatService.deleteMessage(senderID, widget.receiverID, messageId);

        if (!mounted) return;

        setState(() {
          _decryptedMessages.removeWhere((msg) => msg['messageId'] == messageId);
        });
      });

      _pendingDeletionTasks.add(deletionTask);
    } catch (e) {
      print("Error deleting message: $e");
    }
  }

  @override
  void dispose() {
    // Cancel all pending deletion tasks
    for (var task in _pendingDeletionTasks) {
      task.ignore(); // Ignore the result of the task
    }
    _pendingDeletionTasks.clear();

    _messageController.dispose();
    super.dispose();
  }


  void _toggleDisappearingMessages() {
    setState(() {
      _isDisappearingMessagesEnabled = !_isDisappearingMessagesEnabled;
      _isClockButtonVisible = _isDisappearingMessagesEnabled;
    });
  }

  void _showDurationSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Disappearing Duration"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<Duration>(
                title: Text("10 Seconds"),
                value: Duration(seconds: 10),
                groupValue: _disappearingDuration,
                onChanged: (value) {
                  setState(() {
                    _disappearingDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text("1 Minute"),
                value: Duration(minutes: 1),
                groupValue: _disappearingDuration,
                onChanged: (value) {
                  setState(() {
                    _disappearingDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text("1 Hour"),
                value: Duration(hours: 1),
                groupValue: _disappearingDuration,
                onChanged: (value) {
                  setState(() {
                    _disappearingDuration = value!;
                  });
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<Duration>(
                title: Text("24 Hours"),
                value: Duration(hours: 24),
                groupValue: _disappearingDuration,
                onChanged: (value) {
                  setState(() {
                    _disappearingDuration = value!;
                  });
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
      appBar: AppBar(
        title: Text(widget.receiverEmail),
        actions: _isSelectionMode
            ? [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelectedMessages,
            tooltip: "Delete Selected Messages",
          ),
        ]
            : [],
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


  //sSet<String> processedMessageIds = {}; // Store processed message IDs

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

        // Decrypt messages asynchronously while preserving existing ones
        _decryptNewMessages(snapshot.data!.docs);

        return ListView(
          reverse: true,
          children: _decryptedMessages.map((msg) {
            return _buildMessageItem(msg);
          }).toList(),
        );
      },
    );
  }

  void _decryptNewMessages(List<DocumentSnapshot> newMessages) async {
    // Find the last decrypted message ID or timestamp,
    // and only decrypt new messages
    for (var msg in newMessages) {
      if (!_isMessageDecrypted(msg)) {
        await _decryptMessages(newMessages);
      }
    }
  }

  bool _isMessageDecrypted(DocumentSnapshot msg) {
    // Check if the message is already decrypted or stored in local DB
    // Compare by messageId
    return _decryptedMessages.any((message) => message['messageId'] == msg.id);
  }


  Widget _buildMessageItem(Map<String, dynamic> message) {
    final bool isCurrentUser = message['isCurrentUser'];
    final String decryptedMessage = message['message'];
    final String messageId = message['messageId'];

    bool isSelected = _selectedMessageIds.contains(messageId);

    return GestureDetector(
      onLongPress: () {
        _toggleMessageSelection(messageId);
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleMessageSelection(messageId);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade300 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(vertical: 5),
        child: ChatBubble(
          message: decryptedMessage,
          isCurrentUser: isCurrentUser,
          bubbleColor: isSelected
              ? Colors.red.shade300
              : (isCurrentUser ? Colors.green : Colors.blue.shade300),
        ),
      ),
    );
  }
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
      _isSelectionMode = _selectedMessageIds.isNotEmpty;
    });
  }
  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    try {
      String senderID = _authService.getCurrentUser()!.uid;

      for (String messageId in _selectedMessageIds) {
        await _chatService.deleteMessage(senderID, widget.receiverID, messageId);
      }

      setState(() {
        _decryptedMessages.removeWhere((msg) => _selectedMessageIds.contains(msg['messageId']));
        _selectedMessageIds.clear();
        _isSelectionMode = false;
      });

      print("Selected messages deleted.");
    } catch (e) {
      print("Error deleting messages: $e");
    }
  }


  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          // Eye button to toggle disappearing messages
          IconButton(
            icon: Icon(
              Icons.remove_red_eye,
              color: _isDisappearingMessagesEnabled ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleDisappearingMessages,
            tooltip: "Toggle Disappearing Messages",
          ),
          // Clock button to select duration (visible only when disappearing messages is enabled)
          if (_isClockButtonVisible)
            IconButton(
              icon: Icon(Icons.access_time),
              onPressed: () => _showDurationSelectionDialog(context),
              tooltip: "Select Disappearing Duration",
            ),
          Expanded(
            child: MyTextField(
              controller: _messageController,
              hintText: 'Type a message',
              obscuredText: false,
              onChanged: (String) {},
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: sendMessage,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _showAlgorithmSelection(context),
            tooltip: "Change Algorithm",
          ),
        ],
      ),
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
}