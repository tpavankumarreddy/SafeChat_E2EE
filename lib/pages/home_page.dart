import 'dart:convert';

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
import '../data/database_helper.dart'; // Import the DatabaseHelper class

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final x3dhHelper = X3DHHelper();

  final handshakeHandler = HandshakeHandler();

  final AuthService _authService = AuthService();

  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }



  late GlobalKey<ScaffoldState> _scaffoldKey;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> writeSecureData(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      // Write operation is successful
      print("Data written successfully");
    } catch (e) {
      // Write operation failed
      print("Failed to write data: $e");
    }
  }

  Future<void> readSecureData(String key) async {
    try {
      String? value = await _secureStorage.read(key: key);
      if (value != null) {
        // Read operation is successful
        print("Data read successfully: $value");
      } else {
        // Key does not exist
        print("No data found for the key: $key");
      }
    } catch (e) {
      // Read operation failed
      print("Failed to read data: $e");
    }
  }



  final ChatService chatService = ChatService();

  late List<String> addressBookEmails; // List to store address book emails

  @override
  void initState() {
    super.initState();
    // Initialize the address book emails list
    _loadAddressBookEmails(); // Load address book emails from SQLite database
    _scaffoldKey = GlobalKey<ScaffoldState>();

  }

  // Function to handle address book emails change
  void onAddressBookEmailsChanged(List<String> emails) {
    setState(() {
      addressBookEmails = emails; // Update the address book emails
    });
  }

  // Function to load address book emails from SQLite database
  void _loadAddressBookEmails() async {
    List<String> emails = await DatabaseHelper.instance.queryAllEmails();
    setState(() {
      //addressBookEmails = emails; // Update the address book emails
      addressBookEmails = emails.toSet().toList();
    });
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
              style: TextStyle(fontSize: 20)
              ,
            ),

            Text("Try adding emails to address book",
                style: TextStyle(fontSize: 20)),

            Text("in the navigation drawer.",
                style: TextStyle(fontSize: 20))

          ],
        ),
      );
    } else {
      return StreamBuilder(
        stream: ChatService().getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text("Error");
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Text("Loading...");
          }
          return ListView(
            children: snapshot.data!.map<Widget>((userData) {
              return _buildUserListItem(userData, context);
            }).toList(),
          );
        },
      );
    }
  }
  Widget _buildUserListItem(Map<String, dynamic> userData, BuildContext context) {
    final authService = AuthService();
    if (userData["email"] != authService.getCurrentUser()!.email &&
        addressBookEmails.contains(userData["email"])) {
      return UserTile(
        text: userData["email"],
        onTap: () async {

          //readSecureData('shared_Secret_With${userData["email"]}');

          //final secretKey = await readSecureData('shared_Secret_With$userData["email"]');
          String? secretKey = await _secureStorage.read(key: 'shared_Secret_With_${userData["email"]}');

          final handshakeMessage = await handshakeHandler.receiveHandshakeMessage(getCurrentUser()!.uid, userData["uid"]);

          if (secretKey == null) {
            if (handshakeMessage != null) {
              // Bob's side: process the handshake message received from Alice
              print("receiving handshake ....");
              // Function to delete a secret key

              await handshakeHandler.handleReceivedHandshakeMessage('${getCurrentUser()!.email}', userData["email"], handshakeMessage);
              print('Secret key generated and stored for ${userData["email"]}.');
            } else {
              // Alice's side: perform X3DH and send handshake message
              print("performing x3dh....");
              final x3dhResult = await x3dhHelper.performX3DHKeyAgreement('${getCurrentUser()!.email}',userData["email"],0);

              SecretKey sharedSecret = x3dhResult['sharedSecret'];
              int randomIndex = x3dhResult['randomIndex'];


              List<int> sharedSecretBytes = await sharedSecret.extractBytes();

              print("Shared secret: $sharedSecretBytes");

              // // Store the shared secret
              // await _secureStorage.write(
              //     key: 'shared_Secret_With$userData["email"]',
              //     value: base64Encode(sharedSecretBytes));
              //
              // print('Secret key generated and stored for ${userData["email"]}.');
              // final secretKey1 = await _secureStorage.read(key: 'shared_Secret_With$userData["email"]');
              // print(secretKey1);


              writeSecureData('shared_Secret_With_$userData["email"]', base64Encode(sharedSecretBytes));

              print('Secret key generated and stored for ${userData["email"]}.');




              await handshakeHandler.sendHandshakeMessage(getCurrentUser()!.uid, userData["uid"], userData["email"],randomIndex);
              print('Handshake message sent from ${authService.getCurrentUser()!.email} to userData["email"].');
            }
          } else {

            print('Secret key already exists.');
          }


          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverEmail: userData["email"],
                receiverID: userData["uid"],
              ),
            ),
          );
        },
      );
    } else {
      return Container(); // Return an empty container if conditions are not met
    }
  }
}