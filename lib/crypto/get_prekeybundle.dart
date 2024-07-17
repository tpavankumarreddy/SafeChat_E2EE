import 'package:cloud_firestore/cloud_firestore.dart';

class PreKeyBundleRetriever {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getUserPublicKeysByEmail(String email) async {
    QuerySnapshot userSnapshot = await _firestore.collection("user's").where('email', isEqualTo: email).get();
    if (userSnapshot.docs.isNotEmpty) {
      return userSnapshot.docs.first.data() as Map<String, dynamic>;
    } else {
      throw Exception("User not found");
    }
  }
}
