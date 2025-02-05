import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/database_helper.dart';

class GroupChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen for group messages
  Stream<QuerySnapshot> getGroupMessages(String groupID) {
    return _firestore
        .collection("group_chats")
        .doc(groupID)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  // Sync group messages to the local SQLite database
  void syncGroupMessagesToLocalDB(String groupID) {
    getGroupMessages(groupID).listen((snapshot) async {
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String messageID = data.containsKey('messageID') ? data['messageID'] : doc.id;
        String senderID = data['senderID'];
        String message = data['message'];
        String timestamp = data['timestamp'].toDate().toString();

        // Check if the message already exists in the local DB
        bool exists = await DatabaseHelper.instance.messageExists(messageID);
        if (!exists) {
          // Insert into the local SQLite DB
          await DatabaseHelper.instance.insertMessage(
            messageID: messageID,
            senderID: senderID,
            receiverID: groupID, // Use groupID as the "receiver" for group chats
            message: message,
            timestamp: timestamp,
            isCurrentUser: senderID == _firestore.collection("users").doc().id,
          );
        }
      }
    });
  }

  // Send a message to the group chat
  Future<String?> sendGroupMessage(String groupID, String encryptedMessage, String algorithm) async {
    try {
      final Timestamp timestamp = Timestamp.now();
      final currentUserID = _firestore.collection("users").doc().id;

      // Create the message data
      Map<String, dynamic> messageData = {
        'messageID': '', // Will be populated after Firestore generates the ID
        'senderID': currentUserID,
        'message': encryptedMessage,
        'algorithm': algorithm,
        'timestamp': timestamp,
      };

      // Add the message to Firestore
      DocumentReference docRef = await _firestore
          .collection("group_chats")
          .doc(groupID)
          .collection("messages")
          .add(messageData);

      // Update the message with its Firestore-generated ID
      await docRef.update({'messageID': docRef.id});

      return docRef.id; // Return the Firestore message ID
    } catch (e) {
      print("Error sending group message: $e");
      return null;
    }
  }

  // Delete a message from the group chat
  Future<void> deleteGroupMessage(String groupID, String messageID) async {
    try {
      await _firestore
          .collection("group_chats")
          .doc(groupID)
          .collection("messages")
          .doc(messageID)
          .delete();

      // Also delete the message from the local SQLite database
      await DatabaseHelper.instance.deleteMessage(messageID);
    } catch (e) {
      print("Error deleting group message: $e");
    }
  }

  // Retrieve all messages for a specific group
  Future<List<Map<String, dynamic>>> getGroupMessagesFromFirestore(String groupID) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection("group_chats")
          .doc(groupID)
          .collection("messages")
          .orderBy("timestamp", descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print("Error fetching group messages: $e");
      return [];
    }
  }
}