import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:emailchat/data/database_helper.dart';
import '../services/auth/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Profile information
  String _name = "";
  final String _bio = "";
  String _selectedImage = 'lib/images/profile-user.png'; // Default profile image
  final String _imagePath = 'lib/images/pawn.png';

  final AuthService _authService = AuthService();


  User? getCurrentUser() {
    return _authService.getCurrentUser();
  }

  void _handleEditNickname() async {
    // Consider using a form to handle user input
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController nameController = TextEditingController(text: _name);
        return AlertDialog(
          title: const Text('Edit Nickname'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nickname'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, nameController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null) {
      // Update nickname database or user profile (replace with your logic)
      setState(() {
        _name = newName;
      });
      await DatabaseHelper.instance.updateProfileData(_name, _imagePath);

    }
  }

  // @override
  // void initState() {
  //   super.initState();
  //   // Load profile data from database on initialization
  //   _loadProfileData();
  // }

  // Future<void> _loadProfileData() async {
  //   final Map<String, dynamic>? profileData = await DatabaseHelper.instance.queryProfileData();
  //   if (profileData != null) {
  //     setState(() {
  //       _name = profileData[DatabaseHelper._columnName] as String;
  //       _imagePath = profileData[DatabaseHelper._columnImagePath] as String;
  //     });
  //   }
  // }




  // List of profile image assets
  final List<String> _profileImages = [
    'lib/images/1.webp',
    'lib/images/avatar-design.png',
    'lib/images/boy.png',
    'lib/images/game.webp',
    'lib/images/man.png',
    'lib/images/man-2.png',
    'lib/images/profile.png',
    'lib/images/user.png',
    'lib/images/user (1).png',
    'lib/images/woman.png',
    'lib/images/rook.png',
    'lib/images/pawn.png',
    'lib/images/knight.png',
    'lib/images/bishop.png',
    'lib/images/king.png',
    'lib/images/queen.png',
    'lib/images/profile-user.png'

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 20),
            // Profile picture section
            Center(
              child: CircleAvatar(
                radius: 80,
                backgroundImage: AssetImage(_selectedImage),
              ),
            ),


            const SizedBox(height: 40),

            Center(
              child: Text(
                _name.isEmpty ? '${getCurrentUser()!.email}' : _name,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),



            const SizedBox(height: 20),


            const SizedBox(height: 20),



          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        children: [
          SpeedDialChild(
            child: const Icon(Icons.edit),
            label: 'Edit Nickname',
            onTap: _handleEditNickname
          ),
          SpeedDialChild(
            child: const Icon(Icons.person),
            label: 'Change Profile Picture',
            onTap: () {
              _showImageSelectionDialog(context);

            },
          ),
        ],
        child: const Icon(Icons.edit),
      ),
    );
  }

  // Method to show dialog for selecting profile image
  void _showImageSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Profile Picture'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _profileImages.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: AssetImage(_profileImages[index]),
                  ),
                  title: Text('Image ${index + 1}'),
                  onTap: () {
                    setState(() {
                      _selectedImage = _profileImages[index];
                    });
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}