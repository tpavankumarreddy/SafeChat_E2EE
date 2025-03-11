import 'package:SafeChat/main.dart';
import 'package:SafeChat/pages/KeyBackup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'login_page.dart';
import 'privacy_page.dart';
import 'package:SafeChat/pages/themes_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool _isBiometricEnabled = false;
  final LocalAuthentication _auth = LocalAuthentication();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load biometric preference from shared preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  // Save the biometric preference
  Future<void> _saveBiometricPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
  }

  // Enable or disable biometric authentication
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // If enabling biometrics, verify with the user first
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        final isAuthenticated = await _auth.authenticate(
          localizedReason: 'Enable biometric app lock',
          options: const AuthenticationOptions(biometricOnly: true),
        );

        if (isAuthenticated) {
          _saveBiometricPreference(true);
        }
      }
    } else {
      _saveBiometricPreference(false);
    }
  }

  // Function to delete user's Firestore data
  Future<void> deleteUserData(String userId) async {
    try {
      await _firestore.collection("user's").doc(userId).delete();
      // Delete other collections or documents related to the user if needed
      // Example: await _firestore.collection('user_messages').doc(userId).delete();
    } catch (e) {
      throw Exception('Error deleting user data: $e');
    }
  }
  Future<void> deleteAccount(BuildContext parentContext) async {
    final TextEditingController passwordController = TextEditingController();

    // Show dialog to ask for password
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Re-authentication Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your password to proceed with account deletion.'),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                Navigator.of(context).pop(); // Close the dialog

                if (password.isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Password cannot be empty.')),
                  );
                  return;
                }

                try {
                  // Re-authenticate the user
                  final user = FirebaseAuth.instance.currentUser;
                  if (user?.email != null) {
                    final credential = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: password,
                    );

                    await user.reauthenticateWithCredential(credential);

                    // Proceed with account deletion
                    final userId = user.uid;

                    if (userId != null) {
                      // Delete user data from Firestore
                      await deleteUserData(userId);
                    }

                    // Delete the user account
                    await FirebaseAuth.instance.currentUser?.delete();

                    print("Account deleted");

                    if (!mounted) return;

                    // Show account deletion confirmation dialog
                    showDialog(
                      context: parentContext,
                      builder: (context) => AlertDialog(
                        title: const Text("Account Deleted"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MyApp(),
                                ),
                              );
                            },
                            child: const Text('Ok'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  if (e is FirebaseAuthException && e.code == 'wrong-password') {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Incorrect password. Please try again.')),
                    );
                  } else {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Privacy'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Backup and Restore Data'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => KeyBackupManager()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Appearance'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const themesPage()),
              );
            },
          ),
          SwitchListTile(
            title: const Text('Enable App Lock'),
            value: _isBiometricEnabled,
            onChanged: (bool value) async {
              await _toggleBiometric(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Account'),
            onTap: () async {
              await deleteAccount(context);
            },
          ),
        ],
      ),
    );
  }
}