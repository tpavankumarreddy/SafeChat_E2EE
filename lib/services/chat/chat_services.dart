import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String,dynamic>>> getUsersStream() {
    return _firestore.collection("user's").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  Future<void> sendMessage(String receiverID, String message) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    //print('[ChatService - sendMessage] Line 19: sendMessage called with receiverID: $receiverID, message: $message, senderID: $currentUserID');

    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      timestamp: timestamp,
    );

    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    // print('[ChatService - sendMessage] Line 29: Adding message to chatRoomID: $chatRoomID');
    // print('[ChatService - sendMessage] Line 30: Message data: ${newMessage.toMap()}');

    await _firestore.collection("chat_rooms").doc(chatRoomID).collection("messages").add(newMessage.toMap());
  }

  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    //print('[ChatService - getMessages] Line 37: Fetching messages for chatRoomID: $chatRoomID');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
