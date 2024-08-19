import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../components/my_drawer.dart';
import '../components/user_tile.dart';
import '../crypto/X3DHHelper.dart';
import '../crypto/handshake_handler.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_services.dart';
import 'chat_page.dart';
import '../data/database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final x3dhHelper = X3DHHelper();
  final handshakeHandler = HandshakeHandler();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ChatService chatService = ChatService();
  late GlobalKey<ScaffoldState> _scaffoldKey;
  late List<String> addressBookEmails;

  @override
  void initState() {
    super.initState();
    _scaffoldKey = GlobalKey<ScaffoldState>();
    _loadAddressBookEmails(); // Load address book emails with nicknames from SQLite database
  }

  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }

  // Function to handle address book emails change
  void onAddressBookEmailsChanged(List<String> emails) {
    setState(() {
      addressBookEmails = emails;
    });
  }

  // Function to load address book emails with nicknames from SQLite database
  void _loadAddressBookEmails() async {
    List<Map<String, dynamic>> emailNicknames = await DatabaseHelper.instance.queryAllEmailsWithNicknames();
    setState(() {
      addressBookEmails = emailNicknames.map<String>((entry) => (entry['nickname'] ?? entry['email']) as String).toList();
    });
  }
  Future<String?> getUidForEmail(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("user's") // Assuming your user data is stored in a collection called 'users'
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['uid'] as String?;
      } else {
        print('No user found with email $email');
        return null;
      }
    } catch (e) {
      print('Error fetching UID for email $email: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          _scaffoldKey.currentState!.openDrawer();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text("SafeChat"),
        ),
        drawer: MyDrawer(onAddressBookEmailsChanged: onAddressBookEmailsChanged),
        body: _buildUserList(),
      ),
    );
  }

  Widget _buildUserList() {
    if (addressBookEmails.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "Address book is empty.",
              style: TextStyle(fontSize: 20),
            ),
            Text("Try adding emails to address book",
                style: TextStyle(fontSize: 20)),
            Text("in the navigation drawer.",
                style: TextStyle(fontSize: 20)),
          ],
        ),
      );
    } else {
      return ListView.builder(
          itemCount: addressBookEmails.length,
          itemBuilder: (context, index) {
          final name = addressBookEmails[index];

      return UserTile(
        text: name,
        onTap: () async {
          final email = await DatabaseHelper.instance.getEmailByNickname(addressBookEmails[index]);
          final uid = await getUidForEmail(email!);
          final secretKeyString = await _secureStorage.read(key: 'shared_Secret_With_${email}');
          final handshakeMessage = await handshakeHandler.receiveHandshakeMessage(getCurrentUser()!.uid, uid!);

          SecretKey? generatedSecretKey;

          if (secretKeyString == null) {
            if (handshakeMessage != null) {
              // Bob's side: process the handshake message received from Alice
              print("receiving handshake ....");

              await handshakeHandler.handleReceivedHandshakeMessage('${getCurrentUser()!.email}', email, handshakeMessage);
              print('Secret key generated and stored for $email.');
              // Read and decode the generated secret key
              final storedSecretKeyString = await _secureStorage.read(key: 'shared_Secret_With_${email}');
              print(storedSecretKeyString);
              if (storedSecretKeyString != null) {
                final secretKeyBytes = base64Decode(storedSecretKeyString);
                generatedSecretKey = SecretKey(secretKeyBytes);
              }
            } else {
              // Alice's side: perform X3DH and send handshake message
              print("performing x3dh....");
              final x3dhResult = await x3dhHelper.performX3DHKeyAgreement('${getCurrentUser()!.email}', email, 0);

              SecretKey sharedSecret = x3dhResult['sharedSecret'];
              int randomIndex = x3dhResult['randomIndex'];

              List<int> sharedSecretBytes = await sharedSecret.extractBytes();

              print("Shared secret: $sharedSecretBytes");

              // Store the shared secret
              await _secureStorage.write(
                  key: 'shared_Secret_With_${email}',
                  value: base64Encode(sharedSecretBytes));

              print('Secret key generated and stored for $email.');

              await handshakeHandler.sendHandshakeMessage(getCurrentUser()!.uid, uid, name, randomIndex);
              print('Handshake message sent from ${_authService.getCurrentUser()!.email} to $email.');

              generatedSecretKey = sharedSecret;
            }
          } else {
            print('Secret key already exists.');
            final secretKeyBytes = base64Decode(secretKeyString);
            generatedSecretKey = SecretKey(secretKeyBytes);
          }

          if (generatedSecretKey != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  receiverEmail: email,
                  receiverID: uid,
                  secretKey: generatedSecretKey!,
                ),
              ),
            );
          } else {
            print('Error generating or retrieving the secret key.');
          }
        },
      );
    }
    );
  }
}
}
