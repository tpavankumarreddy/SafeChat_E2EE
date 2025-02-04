// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:SafeChat/components/chat_bubble.dart';
// import 'package:SafeChat/components/my_textfield.dart';
// import 'package:SafeChat/services/auth/auth_service.dart';
// import 'package:SafeChat/services/chat/chat_services.dart';
// import 'package:flutter/material.dart';
// import 'package:SafeChat/crypto/Encryption_helper.dart';
// import 'package:cryptography/cryptography.dart';
//
// import '../data/database_helper.dart';
//
// class GroupChatPage extends StatefulWidget {
//   final String groupId;
//   final String groupName;
//   final List<String> members;
//   final SecretKey adminSecretKey;
//
//   GroupChatPage({
//     super.key,
//     required this.groupId,
//     required this.groupName,
//     required this.members,
//     required this.adminSecretKey,
//   });
//
//   @override
//   _GroupChatPageState createState() => _GroupChatPageState();
// }
//
// class _GroupChatPageState extends State<GroupChatPage> {
//   final TextEditingController _messageController = TextEditingController();
//   final ChatService _chatService = ChatService();
//   final AuthService _authService = AuthService();
//   final EncryptionHelper _encryptionHelper = EncryptionHelper();
//
//   SecretKey? groupKey;
//   Map<String, SecretKey> encryptedGroupKeys = {};
//   late Stream<QuerySnapshot> _messageStream;
//   List<Map<String, dynamic>> _decryptedMessages = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeGroupKey();
//     _messageStream = _chatService.getGroupMessages(widget.groupId);
//     _messageStream.listen((snapshot) {
//       if (snapshot.docs.isNotEmpty) {
//         print("[GroupChatPage] New messages received");
//         _decryptMessages(snapshot.docs);
//       }
//     });
//   }
//
//   Future<void> _initializeGroupKey() async {
//     if (_authService.isCurrentUserAdmin(widget.groupId)) {
//       final rawKey = utf8.encode(widget.groupId + DateTime.now().toIso8601String());
//       final digest = await Sha256().hash(rawKey);
//       groupKey = SecretKey(digest.bytes);
//       _encryptGroupKeyForMembers();
//     } else {
//       // Fetch encrypted group key and decrypt it
//       String encryptedKey = await _chatService.getEncryptedGroupKey(widget.groupId, _authService.getCurrentUser()!.uid);
//       groupKey = await _encryptionHelper.decryptGroupKey(encryptedKey, widget.adminSecretKey);
//     }
//   }
//
//   Future<void> _encryptGroupKeyForMembers() async {
//     for (String member in widget.members) {
//       SecretKey memberKey = await _authService.getSharedSecretKey(member);
//       String encryptedKey = await _encryptionHelper.encryptGroupKey(groupKey!, memberKey);
//       encryptedGroupKeys[member] = SecretKey(utf8.encode(encryptedKey));
//       await _chatService.storeEncryptedGroupKey(widget.groupId, member, encryptedKey);
//     }
//   }
//
//   Future<void> sendMessage() async {
//     if (_messageController.text.isNotEmpty && groupKey != null) {
//       final encryptedData = await _encryptionHelper.encryptMessage(_messageController.text, groupKey!);
//       await _chatService.sendGroupMessage(widget.groupId, jsonEncode(encryptedData));
//       _messageController.clear();
//     }
//   }
//
//   Future<void> _decryptMessages(List<DocumentSnapshot> docs) async {
//     List<Map<String, dynamic>> newMessages = [];
//     for (var doc in docs) {
//       Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
//       if (data.isEmpty) continue;
//
//       final messageJson = data['message'];
//       try {
//         Map<String, dynamic> messageData = jsonDecode(messageJson);
//         final decryptedMessage = await _encryptionHelper.decryptMessage(
//           messageData['cipherText'],
//           messageData['nonce'],
//           groupKey!,
//         );
//
//         newMessages.add({
//           'message': decryptedMessage,
//           'senderID': data['senderID'],
//         });
//       } catch (e) {
//         print("Error decrypting message: $e");
//       }
//     }
//
//     if (newMessages.isNotEmpty) {
//       setState(() {
//         _decryptedMessages.insertAll(0, newMessages);
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.groupName)),
//       body: Column(
//         children: [
//           Expanded(child: _buildMessageList()),
//           _buildUserInput(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageList() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: _messageStream,
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return Center(child: Text("Error: ${snapshot.error}"));
//         }
//
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }
//
//         if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//           return Center(child: Text("No messages yet"));
//         }
//
//         _decryptMessages(snapshot.data!.docs);
//
//         return ListView(
//           reverse: true,
//           children: _decryptedMessages.map((msg) {
//             return ChatBubble(
//               message: msg['message'],
//               isCurrentUser: msg['senderID'] == _authService.getCurrentUser()!.uid,
//             );
//           }).toList(),
//         );
//       },
//     );
//   }
//
//   Widget _buildUserInput() {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 20.0),
//       child: Row(
//         children: [
//           Expanded(
//             child: MyTextField(
//               controller: _messageController,
//               hintText: 'Type a message',
//               obscuredText: false,
//               onChanged: (String) {},
//             ),
//           ),
//           IconButton(
//             icon: Icon(Icons.send),
//             onPressed: sendMessage,
//           ),
//         ],
//       ),
//     );
//   }
// }
