import 'dart:convert';
import 'dart:io';
import 'package:SafeChat/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';

class RestoreBackupPage extends StatefulWidget {
  const RestoreBackupPage({super.key});

  @override
  _RestoreBackupPageState createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends State<RestoreBackupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isRestoring = false;

  Future<void> restoreBackup() async {
    setState(() => _isRestoring = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null) {
        setState(() => _isRestoring = false);
        return;
      }

      File backupFile = File(result.files.single.path!);
      String encryptedData = await backupFile.readAsString();
      if (encryptedData.isEmpty) {
        throw Exception("Backup file is empty.");
      }

      String password = _passwordController.text.trim();
      if (password.isEmpty) {
        throw Exception("Password cannot be empty.");
      }

      Map<String, dynamic> decryptedData = _decryptData(encryptedData, password);
      if (decryptedData.isEmpty) {
        throw Exception("Incorrect password or corrupted backup file.");
      }

      await _restoreSecureStorage(decryptedData['keys']);

      if (decryptedData.containsKey('database') && decryptedData['database'] != null) {
        await _restoreDatabase(decryptedData['database'], password);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backup restored successfully!")),
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(isLoggedIn: true),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to restore backup: $e")),
      );
    }

    setState(() => _isRestoring = false);
  }

  /// **Decrypt Data Using AES-CBC**
  Map<String, dynamic> _decryptData(String encryptedData, String password) {
    try {
      final Map<String, dynamic> dataMap = jsonDecode(encryptedData);
      if (!dataMap.containsKey('keys')) {
        throw Exception('Invalid backup file format: Missing keys.');
      }

      final Map<String, dynamic> encryptedKeysMap = jsonDecode(dataMap['keys']);
      if (!encryptedKeysMap.containsKey('iv') || !encryptedKeysMap.containsKey('data')) {
        throw Exception('Invalid encrypted keys format. Missing IV or Data.');
      }

      final iv = encrypt.IV.fromBase64(encryptedKeysMap['iv']);
      final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      String decryptedKeys = encrypter.decrypt64(encryptedKeysMap['data'], iv: iv);

      return {
        "keys": jsonDecode(decryptedKeys),
        "database": dataMap.containsKey('database') ? dataMap['database'] : null,
      };
    } catch (e) {
      return {};
    }
  }

  /// **Restore Secure Storage Data**
  Future<void> _restoreSecureStorage(Map<String, dynamic> backupData) async {
    for (String key in backupData.keys) {
      if (key.startsWith("identityKeyPair") ||
          key.startsWith("preKeyPair") ||
          key.startsWith("oneTimePreKeyPair") ||
          key.startsWith("shared_Secret") ||
          key.startsWith("group_secret_key")) {
        await _secureStorage.write(key: key, value: backupData[key]);
      }
    }
  }

  Future<void> _restoreDatabase(String encryptedDbBase64, String password) async {
    try {
      List<int> encryptedDbBytes = base64Decode(encryptedDbBase64);
      final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));

      final ivBytes = encryptedDbBytes.sublist(0, 16);
      final encryptedBytes = encryptedDbBytes.sublist(16);

      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      final decryptedDbBytes = encrypter.decryptBytes(
        encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
        iv: iv,
      );

      String dbPath = await getDatabasesPath();
      final String currentUserID = _auth.currentUser!.uid;
      String fullDbPath = "$dbPath/user_database$currentUserID.db";

      File dbFile = File(fullDbPath);
      await dbFile.writeAsBytes(decryptedDbBytes, flush: true);
    } catch (e) {
      print("Database Restore Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Restore Backup"),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your backup password",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "Backup Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isRestoring ? null : restoreBackup,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isRestoring
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Restore Backup",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
