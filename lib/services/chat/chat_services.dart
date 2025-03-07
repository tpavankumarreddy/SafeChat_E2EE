import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/database_helper.dart';
import '../../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("user's").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Stream<QuerySnapshot> listenForMessages(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  void syncMessagesToLocalDB(String userID, String otherUserID) {
    listenForMessages(userID, otherUserID).listen((snapshot) async {
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;

        String messageID = data.containsKey('messageID')
            ? data['messageID']
            : doc.id;
        String senderID = data['senderID'];
        String receiverID = data['receiverID'];
        String message = data['message'];
        String timestamp = data['timestamp'].toDate().toString();
        bool isCurrentUser = senderID == _auth.currentUser!.uid;

        // Log message data to check if it's being retrieved correctly
        print('Received message: $messageID, $senderID -> $receiverID');

        // Check if the message already exists in local DB
        bool exists = await DatabaseHelper.instance.messageExists(messageID);
        print('Message exists: $exists');  // Debug log

        if (!exists) {
          // Insert into local SQLite DB
          int result = await DatabaseHelper.instance.insertMessage(
            messageID: messageID,
            senderID: senderID,
            receiverID: receiverID,
            message: message,
            timestamp: timestamp,
            isCurrentUser: isCurrentUser,
          );
          print('Message inserted into local DB: $result');  // Debug log
        }
      }
    });
  }


  Future<String?> sendMessage(String receiverID, String message, String algorithm) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      timestamp: timestamp,
      algorithm: algorithm,
    );

    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    DocumentReference docRef = await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .add(newMessage.toMap());

    String messageID = docRef.id;  // Get Firestore message ID
    return messageID;
  }


  Future<void> deleteMessage(String userID, String otherUserID, String messageID) async {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .doc(messageID)
        .delete();
    await DatabaseHelper.instance.deleteMessage(messageID);
  }

  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
