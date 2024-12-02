import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("user's").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  Future<void> notifyAlgorithmChange(String receiverID, String newAlgorithm) async {
    final String currentUserID = _auth.currentUser!.uid;

    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    try {
      await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("algorithmchangenotifier")
          .add({
        'senderID': currentUserID,
        'receiverID': receiverID,
        'newAlgorithm': newAlgorithm,
        'timestamp': Timestamp.now(),
        'status': 'pending', // 'pending', 'accepted', or 'declined'
      });
    } catch (e) {
      print("Error notifying algorithm change: $e");
      throw e; // Propagate the error
    }
  }

  Future<void> respondToAlgorithmChange(
      String chatRoomID, String notificationID, bool isAccepted, String newAlgorithm) async {
    try {
      final notificationDoc = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("algorithmchangenotifier")
          .doc(notificationID)
          .get();

      if (!notificationDoc.exists) throw "Notification does not exist";

      if (isAccepted) {
        await _firestore
            .collection("chat_rooms")
            .doc(chatRoomID)
            .collection("algorithmchangenotifier")
            .doc(notificationID)
            .update({'status': 'accepted'});

        // Update the chat room's default algorithm
        await _firestore.collection("chat_rooms").doc(chatRoomID).update({
          'algorithm': newAlgorithm,
        });

        // Notify both users of the algorithm change
        _notifyUsersOfAlgorithmChange(chatRoomID, newAlgorithm);
      } else {
        await _firestore
            .collection("chat_rooms")
            .doc(chatRoomID)
            .collection("algorithmchangenotifier")
            .doc(notificationID)
            .update({'status': 'declined'});
      }
    } catch (e) {
      print("Error responding to algorithm change: $e");
      throw e; // Propagate the error
    }
  }


  Stream<List<Map<String, dynamic>>> getAlgorithmChangeNotifications(
      String chatRoomID, String userID) {
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("algorithmchangenotifier")
        .where('receiverID', isEqualTo: userID)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final notification = doc.data();
        notification['id'] = doc.id; // Include the document ID for actions
        return notification;
      }).toList();
    });
  }

  Future<void> sendMessage(
      String receiverID, String message, String algorithm) async {
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

    await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  Stream<String?> getAlgorithm(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .snapshots()
        .map((snapshot) => snapshot.data()?['algorithm'] as String?);
  }

  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  Future<void> _notifyUsersOfAlgorithmChange(
      String chatRoomID, String newAlgorithm) async {
    try {
      final chatRoomDoc = await _firestore.collection("chat_rooms").doc(chatRoomID).get();
      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data();
        final participants = data?['participants'] as List<dynamic>?;

        if (participants != null) {
          for (var userID in participants) {
            await _firestore
                .collection("notifications")
                .doc(userID)
                .set({
              'message': 'Algorithm has been updated to $newAlgorithm',
              'chatRoomID': chatRoomID,
              'timestamp': Timestamp.now(),
            });
          }
        }
      }
    } catch (e) {
      print("Error notifying users of algorithm change: $e");
    }
  }
}
