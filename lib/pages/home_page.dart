import 'dart:convert';

import 'package:SafeChat/pages/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../components/group_notifications.dart';
import '../components/group_tile.dart';
import '../components/my_drawer.dart';
import '../components/user_tile.dart';
import '../crypto/X3DHHelper.dart';
import '../services/auth/auth_service.dart';
import '../services/chat/chat_services.dart';
import 'Group_chatpage.dart';
import 'address_book_page.dart';
import 'chat_page.dart';
import '../data/database_helper.dart';
import '../crypto/groupkey.dart';

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


  late List<Map<String, dynamic>> groupDataList = []; // Store fetched group data

  void _loadGroupChats() async {
    List<Map<String, dynamic>> groupList = await DatabaseHelper.instance
        .queryAllGroups();
    print('Loaded groups: $groupList'); // Debug log

    setState(() {
      groupChats = groupList.map((entry) => entry['GroupName'] as String).toList();

      groupDataList = groupList.map((entry) {
        return {
          'GroupName': entry['GroupName'],
        };
      }).toList();
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
          actions: [
            GroupNotifications(),  // 🔔 Notification Icon in AppBar
          ],
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
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group Name Field
                    TextField(
                      controller: groupNameController,
                      decoration: const InputDecoration(labelText: 'Group Name'),
                    ),
                    const SizedBox(height: 10),

                    // Dynamically Added Member Fields
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

                    // Add Member Button (Limit: 5)
                    if (memberControllers.length < 5)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            memberControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Member'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    String groupName = groupNameController.text.trim();
                    List<String> members = memberControllers
                        .map((controller) => controller.text.trim())
                        .where((email) => email.isNotEmpty)
                        .toList();

                    User? currentUser = FirebaseAuth.instance.currentUser;
                    if (groupName.isNotEmpty && members.isNotEmpty && currentUser != null) {
                      // Generate unique group ID
                      String groupId = FirebaseFirestore.instance.collection('groups').doc().id;

                      // Group data to store in Firestore
                      Map<String, dynamic> groupData = {
                        "groupId": groupId,
                        "groupName": groupName,
                        "members": members,
                        "admin": currentUser.email, // Current user is admin
                        "groupSecretKey": "", // Empty at the start
                        "createdAt": FieldValue.serverTimestamp(),
                      };

                      Map<String, dynamic> groupData1 = {
                        "groupId": groupId,
                        "messages": [] ,
                        "createdAt": FieldValue.serverTimestamp(),
                      };

                      print("object");
                      // Store in Firestore under 'groups' collection
                      await FirebaseFirestore.instance.collection('groups').doc(groupId).set(groupData);
                      await FirebaseFirestore.instance.collection('group_chats').doc(groupId).set(groupData1);
                      String? adminEmail= currentUser.email;
                      print(members);


                      Future<List<String>> getUids(List<String> members) async {
                        List<String?> uids = await Future.wait(
                          members.map((email) => getUidForEmail(email)),
                        );

                        return uids.whereType<String>().toList(); // Filters out null values
                      }

                      List<String> uids = await getUids(members);

                      // Generate and store group key
                      await _generateGroupKey(groupId, members);




                      await announceGroupToMembers(groupId, adminEmail!, groupName, uids);

                      await DatabaseHelper.instance.insertGroup(
                        groupName,
                        members,
                      );
                      // ✅ Add the new group to local groupChats list
                      setState(() {
                        groupChats.add(groupName);
                      });

                      _loadGroupChats(); // ✅ Call the function normally
                      setState(() {}); // Ensure UI updates properly


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

// Function to generate and store the group key in Firestore
  Future<void> _generateGroupKey(String groupId, List<String> members) async {
    try {
      // Fetch encrypted group keys for each member
      Map<String, String> encryptedKeys = await createAndDistributeGroupKey(members, groupId);

      if (encryptedKeys.isEmpty) {
        print("Failed to generate encrypted group keys.");
        return;
      }

      // Update Firestore with encrypted group keys
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        "groupSecretKeys": encryptedKeys,
      });

      print("Encrypted group keys stored successfully for group $groupId");
    } catch (e) {
      print("Error generating group key: $e");
    }
  }


// Function to build user list
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
                print("Secret key doesn't exist.");
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

          // Find the corresponding group data from groupDataList
          final groupData = groupDataList.firstWhere(
                (group) => group['GroupName'] == groupName,
            orElse: () => {}, // Return empty map if not found
          );

          // Extract group ID from Firestore (or local DB)
          String groupId = groupData.isNotEmpty && groupData.containsKey('GroupId')
              ? groupData['GroupId'].toString()
              : '';

          // Placeholder for group secret key (for testing purposes)
          SecretKey groupSecretKey =
          SecretKey([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]); // Example placeholder key

          // Return a single GroupTile with only the group name
          return GroupTile(
            groupName: groupName,
            onTap: () {
              // Navigate to the GroupChatPage with the required parameters
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatPage(
                    groupName: groupName,
                    groupID: groupId,
                    secretKey: groupSecretKey,
                  ),
                ),
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
