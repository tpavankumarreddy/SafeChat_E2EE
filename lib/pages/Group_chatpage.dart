import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:SafeChat/components/chat_bubble.dart';
import 'package:SafeChat/components/my_textfield.dart';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/services/chat/group_services.dart';
import 'package:flutter/material.dart';
import 'package:SafeChat/crypto/Encryption_helper.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import '../data/database_helper.dart';

class GroupChatPage extends StatefulWidget {
  final String groupName;
  late String groupId;
  GroupChatPage({
    Key? key,
    required this.groupName,
    required this.groupId,
  }) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  String? groupId;
  final TextEditingController _messageController = TextEditingController();
  final GroupChatService _chatService = GroupChatService();
  final AuthService _authService = AuthService();
  final EncryptionHelper _encryptionHelper = EncryptionHelper();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late final String groupSecretKey;
  late SecretKey groupkey = SecretKey(List.filled(32, 0)); // Placeholder key

  Map<String, SecretKey> derivedKeys = {};
  String _selectedAlgorithm = 'AES';

  late final Stream<QuerySnapshot> _messageStream;
  List<Map<String, dynamic>> _decryptedMessages = [];

  // Disappearing messages feature
  bool _isDisappearingMessagesEnabled = false;
  Duration _disappearingDuration = Duration(seconds: 10); // Default duration
  bool _isClockButtonVisible = false;

  // Track processed messages and pending deletion tasks
  Set<String> processedMessageIds = {};
  final Set<Future<void>> _pendingDeletionTasks = {};

  @override
  void initState() {
    super.initState();
    _initializeGroupChat();
    _initializeDerivedKeys();
  }

  Future<void> _initializeGroupChat() async {
    //await _fetchGroupID();
    loadGroupSecretKey(widget.groupId);
    _secureFlag();

    // Initialize the group message stream using the groupID.
    _messageStream = _chatService.getGroupMessages(widget.groupId);

    // Optionally, sync group messages to the local database.
    _chatService.syncGroupMessagesToLocalDB(widget.groupId);

    // Listen for new group messages and decrypt them.
    _messageStream.listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        print("[GroupChatPage] New group messages received");
        await _decryptMessages(snapshot.docs);
        if (mounted) {
          setState(() {}); // Update UI after decryption
        }
      }
    });
  }




  Future<void> _secureFlag() async {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);  }

  Future<void> loadGroupSecretKey(String groupID) async {
    print("Loading group secret key for groupID: $groupID");

    // Read the base64 encoded key from storage
    String? storedKey = await _secureStorage.read(key: 'group_secret_key_$groupID');

    if (storedKey == null) {
      print("Error: Group secret key not found!");
      return;
    }

    print("Base64-encoded key length: ${storedKey.length}");

    // Decode the key
    List<int> decodedKey = base64Decode(storedKey);
    print("Decoded key length: ${decodedKey.length}");
    // Check the length after decoding
    if (decodedKey.length != 32) {
      print("Error: Decoded group key length is not 32 bytes. Got ${decodedKey.length} bytes.");
      return;
    }
    // Store the decoded key
    groupkey = SecretKey(decodedKey);
    print("Group secret key loaded successfully.");
  }

  Future<void> _initializeDerivedKeys() async {
    try {
      final masterKeyBytes = await groupkey.extractBytes();

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
      // Encrypt the message with the selected algorithm.
      final encryptedData = await _encryptionHelper.encryptMessage(
        _messageController.text,
        groupkey,
        algorithm: _selectedAlgorithm,
      );

      print("[sendMessage] Encrypted group message: $encryptedData");

      // Prepare message data.
      Map<String, String> messageData = {
        'cipherText': encryptedData['cipherText'],
        'nonce': encryptedData['nonce'],
      };

      // Send the message to the group chat collection.
      String? messageId = await _chatService.sendGroupMessage(
        widget.groupId,
        jsonEncode(messageData),
        _selectedAlgorithm,
      );

      print("[sendMessage] Group message sent with ID: $messageId");

      // If disappearing messages are enabled, schedule deletion.
      if (_isDisappearingMessagesEnabled && messageId != null) {
        _scheduleMessageDeletion(messageId);
      }

      // Clear the text field.
      _messageController.clear();
    }
  }

  Future<void> _decryptMessages(List docs) async {
    if (!mounted) return;

    for (var doc in docs) {
      String messageId = doc.id;
      if (processedMessageIds.contains(messageId)) continue;

      Map data = doc.data() as Map? ?? {};
      if (data.isEmpty) continue;

      final String algorithm = data['algorithm'] ?? 'AES';
      final messageJson = data['message'];

      try {
        Map messageData = jsonDecode(messageJson);
        final cipherTextBase64 = messageData['cipherText'] ?? '';
        final nonceBase64 = messageData['nonce'] ?? '';
        //final SecretKey? key = derivedKeys[algorithm];

        //print(key?.extractBytes());
        print(cipherTextBase64);
        print(nonceBase64);
        if (cipherTextBase64.isEmpty || nonceBase64.isEmpty) {
          continue; // Skip if any necessary data is missing.
        }

        final decryptedMessage = await _encryptionHelper.decryptMessage(
          cipherTextBase64,
          nonceBase64,
          groupkey,
          algorithm: algorithm,
        );

        // Insert the decrypted message at the beginning of the list.
        _decryptedMessages.insert(0, {
          'message': decryptedMessage,
          'messageId': messageId,
          'isCurrentUser':
          data['senderID'] == _authService.getCurrentUser()!.uid,
          'isAlgorithmChange': messageData['isAlgorithmChange'] ?? false,
        });

        // Mark this message as processed.
        processedMessageIds.add(messageId);
      } catch (e) {
        print("Error decrypting group message: $e");
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleMessageDeletion(String messageId) async {
    try {
      String? currentUserId = _authService.getCurrentUser()?.uid;
      if (currentUserId == null) return;

      final deletionTask = Future.delayed(_disappearingDuration).then((_) async {
        if (!mounted) return;

        await _chatService.deleteGroupMessage(widget.groupId, messageId);

        if (!mounted) return;

        setState(() {
          _decryptedMessages.removeWhere((msg) => msg['messageId'] == messageId);
        });
      });

      _pendingDeletionTasks.add(deletionTask);
    } catch (e) {
      print("Error deleting group message: $e");
    }
  }

  @override
  void dispose() {
    // Cancel pending deletion tasks.
    for (var task in _pendingDeletionTasks) {
      task.ignore();
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
                title: Text("SM4-128"),
                value: "SM4",
                groupValue: _selectedAlgorithm,
                onChanged: (value) {
                  _onAlgorithmSelected(value!);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<String>(
                title: Text("Blowfish-256"),
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

    // Send an algorithm change message to notify all group members.
    final algorithmChangeMessage =
        "Encryption algorithm changed to $_selectedAlgorithm";

    try {
      final selectedKey = derivedKeys[_selectedAlgorithm];
      if (selectedKey == null) {
        throw Exception("No derived key found for algorithm $_selectedAlgorithm.");
      }

      final encryptedData = await _encryptionHelper.encryptMessage(
        algorithmChangeMessage,
        selectedKey,
        algorithm: _selectedAlgorithm,
      );

      await _chatService.sendGroupMessage(
        widget.groupId,
        jsonEncode({
          'cipherText': encryptedData['cipherText'],
          'nonce': encryptedData['nonce'],
          'isAlgorithmChange': true,
        }),
        _selectedAlgorithm,
      );

      print("Group algorithm change message sent successfully.");
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

    // Use different bubble colors for algorithm change messages or normal chats.
    final bubbleColor = isAlgorithmChange
        ? Colors.orangeAccent
        : (isCurrentUser ? Colors.green : Colors.blue.shade300);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: ChatBubble(
        message: decryptedMessage,
        isCurrentUser: isCurrentUser,
        bubbleColor: bubbleColor,
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
        // Decrypt only new messages.
        _decryptNewMessages(snapshot.data!.docs);

        return ListView(
          reverse: true,
          children: _decryptedMessages.map((msg) => _buildMessageItem(msg)).toList(),
        );
      },
    );
  }

  void _decryptNewMessages(List<DocumentSnapshot> newMessages) async {
    for (var msg in newMessages) {
      if (!_isMessageDecrypted(msg)) {
        await _decryptMessages(newMessages);
      }
    }
  }

  bool _isMessageDecrypted(DocumentSnapshot msg) {
    return _decryptedMessages.any((message) => message['messageId'] == msg.id);
  }

  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          // Toggle disappearing messages.
          IconButton(
            icon: Icon(
              Icons.remove_red_eye,
              color: _isDisappearingMessagesEnabled ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleDisappearingMessages,
            tooltip: "Toggle Disappearing Messages",
          ),
          // Button to select the disappearing duration.
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
              onChanged: (value) {},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }
}
