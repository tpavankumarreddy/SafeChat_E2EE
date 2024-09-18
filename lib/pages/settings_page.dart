import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'privacy_page.dart';
import 'package:SafeChat/pages/themes_data.dart';
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
          // Other settings...
        ],
      ),
    );
  }
}