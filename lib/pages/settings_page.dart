import 'package:emailchat/pages/themes_data.dart';
import 'package:flutter/material.dart';
import 'privacy_page.dart';  // Import the PrivacyPage
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Assuming you use this for saving preferences

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBiometricEnabled = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  Future<void> _saveBiometricPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        final isAuthenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric settings',
          options: const AuthenticationOptions(
            biometricOnly: true,
          ),
        );

        if (isAuthenticated) {
          // Handle successful biometric authentication
          print("Biometric authentication successful");
        } else {
          // Handle failed biometric authentication
          print("Biometric authentication failed");
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
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
            title: const Text('Enable Biometric Registration'),
            value: _isBiometricEnabled,
            onChanged: (bool value) async {
              if (value) {
                await _authenticateWithBiometrics();
              }
              setState(() {
                _isBiometricEnabled = value;
                _saveBiometricPreference(value);
              });
            },
          ),
        ],
      ),
    );
  }
}
