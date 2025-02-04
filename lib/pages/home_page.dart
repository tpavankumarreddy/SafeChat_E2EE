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
import 'address_book_page.dart';
import 'chat_page.dart';
import '../data/database_helper.dart';

class HomePage extends StatefulWidget {
  bool isLoggedIn;

  HomePage({super.key, required this.isLoggedIn});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Track selected tab (0: Chats, 1: Groups)
  String? userEmail;
  final x3dhHelper = X3DHHelper();
  final settings = SettingsPageState();
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ChatService chatService = ChatService();
  late GlobalKey<ScaffoldState> _scaffoldKey;
  late List<String> addressBookEmails=[];
  late List<String> groupChats=[]; // Store group chat names

  @override
  void initState() {
    super.initState();
    userEmail = getUserEmail();
    _scaffoldKey = GlobalKey<ScaffoldState>();
    _loadAddressBookEmails();
    _loadGroupChats(); // Load group chats
    if (widget.isLoggedIn) {
      _checkPrivateKeysAndPrompt(context);
    }
  }

  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }

  String? getUserEmail() {
    User? user = getCurrentUser();
    return user?.email;
  }

  void onAddressBookEmailsChanged(List<String> emails) {
    setState(() {
      addressBookEmails = emails;
    });
  }

  void _loadAddressBookEmails() async {
    List<Map<String, dynamic>> emailNicknames =
    await DatabaseHelper.instance.queryAllEmailsWithNicknames();
    setState(() {
      addressBookEmails = emailNicknames
          .map<String>((entry) => (entry['nickname'] ?? entry['email']) as String)
          .toList();
    });
  }

  void _loadGroupChats() async {
    List<Map<String, dynamic>> groupList = await DatabaseHelper.instance.queryAllGroups();
    setState(() {
      groupChats = groupList.map<String>((entry) => entry['group_name'] as String).toList();
    });
  }


  Future<bool> _hasPrivateKeys(String userId) async {
    String? userPreKeyPrivateBase64 =
    await _secureStorage.read(key: "identityKeyPairPrivate$userEmail");
    return userPreKeyPrivateBase64 != null && userPreKeyPrivateBase64.isNotEmpty;
  }

  Future<void> _checkPrivateKeysAndPrompt(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      bool hasKeys = await _hasPrivateKeys(user.uid);
      if (!hasKeys) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Invalid Login Detected!'),
              content: const Text(
                  'You must log in on the device where you first registered.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Log Out'),
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
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildUserList(),
            _buildGroupList(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: 'Groups',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (_currentIndex == 1) {
              _showCreateGroupDialog();
            } else if(_currentIndex ==0) {
              List<String>? result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddressBookPage(onEmailsChanged: onAddressBookEmailsChanged,),
                ),
              );
            } else {

            }
          },
          child: Icon(_currentIndex == 0 ? Icons.message : Icons.group_add),
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      ),
    );
  }
  void _showCreateGroupDialog() {
    TextEditingController groupNameController = TextEditingController();
    List<TextEditingController> memberControllers = [TextEditingController()];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( // To update UI dynamically
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group Name Text Field
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(labelText: 'Group Name'),
                    ),

                    const SizedBox(height: 10),

                    // Dynamically Added Member Text Fields
                    Column(
                      children: List.generate(memberControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: memberControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Member ${index + 1} Email',
                                  ),
                                ),
                              ),

                              // Remove Member Button (except for first field)
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    setState(() {
                                      memberControllers.removeAt(index);
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 10),

                    // Add Member Button (Max 5)
                    if (memberControllers.length < 5)
                      ElevatedButton.icon(
                        onPressed: () {
                          if (memberControllers.length < 5) {
                            setState(() {
                              memberControllers.add(TextEditingController());
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Member'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Close dialog
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    String groupName = groupNameController.text.trim();
                    List<String> members = memberControllers
                        .map((controller) => controller.text.trim())
                        .where((email) => email.isNotEmpty)
                        .toList();

                    if (groupName.isNotEmpty && members.isNotEmpty) {
                      await DatabaseHelper.instance.insertGroup(groupName, members);
                      _loadGroupChats(); // Refresh UI
                      Navigator.pop(context); // Close dialog
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildUserList() {
    if (addressBookEmails.isEmpty) {
      return _emptyStateMessage("Address book is empty.");
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
              final secretKeyString = await _secureStorage.read(key: 'shared_Secret_With_$email');

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
        },
      );
    }
  }

  Widget _buildGroupList() {
    if (groupChats.isEmpty) {
      return _emptyStateMessage("No groups available.");
    } else {
      return ListView.builder(
        itemCount: groupChats.length,
        itemBuilder: (context, index) {
          final groupName = groupChats[index];

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.queryAllGroups(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Text('No groups found');
              }

              final groupData = snapshot.data!.firstWhere(
                    (group) => group['group_name'] == groupName,
                orElse: () => {},
              );

              String members = groupData['members'] ?? 'No members';

              return ListTile(
                title: Text(groupName),
                subtitle: Text('Members: $members'),
                leading: Icon(Icons.group),
                onTap: () {
                  // Navigate to group chat screen (to be implemented)
                },
              );
            },
          );
        },
      );
    }
  }


  Widget _emptyStateMessage(String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}
