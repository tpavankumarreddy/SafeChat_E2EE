import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final Timestamp timestamp;
  final String algorithm;

  Message( {
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
    required this.algorithm,

  });

  // convert to a map
  Map<String,dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': receiverID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'timestamp' : timestamp,
      'algorithm': algorithm, // Include algorithm in the map

    };
  }
}
