import 'dart:convert';

import 'package:SafeChat/pages/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../components/my_drawer.dart';
import '../components/user_tile.dart';
import '../crypto/X3DHHelper.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_services.dart';
import 'chat_page.dart';
import '../data/database_helper.dart';

class HomePage extends StatefulWidget {
   bool isLoggedIn; // Add this line

   HomePage({super.key, required this.isLoggedIn});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? userEmail;
  final x3dhHelper = X3DHHelper();
  final settings = SettingsPageState();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ChatService chatService = ChatService();
  late GlobalKey<ScaffoldState> _scaffoldKey;
  late List<String> addressBookEmails;

  @override
  void initState() {
    super.initState();
    userEmail = getUserEmail();
    _scaffoldKey = GlobalKey<ScaffoldState>();
    _loadAddressBookEmails(); // Load address book emails with nicknames from SQLite database
    if(widget.isLoggedIn= true){
      _checkPrivateKeysAndPrompt(context);
    }
  }

  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }

  String? getUserEmail() {
    User? user = getCurrentUser();
    return user?.email;  // Access the email if user is not null
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

  Future<bool> _hasPrivateKeys(String userId) async {
    String? userPreKeyPrivateBase64 = await _secureStorage.read(key: "identityKeyPairPrivate$userEmail");
    if (userPreKeyPrivateBase64 != null && userPreKeyPrivateBase64.isNotEmpty) {
      return true;
    }
    return false;
  }

  Future<void> _checkPrivateKeysAndPrompt(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool hasKeys = await _hasPrivateKeys(user.uid);
      if (!hasKeys) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Private Keys Found'),
              content: const Text('You do not have private keys. Do you want to log out or delete your account and Register again?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Log Out'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await settings.deleteAccount(context);
                  },
                  child: const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      }
    }
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
          print(email);
          if (email == null) {
            print('No email found for the nickname');
            return;
          }
          final uid = await getUidForEmail(email);
          if (uid == null) {
            print('No UID found for email $email');
            return;
          }
          final secretKeyString = await _secureStorage.read(key: 'shared_Secret_With_${email}');

          SecretKey? generatedSecretKey;

          if (secretKeyString == null) {
            print("Secret key doesn't exists.");
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
