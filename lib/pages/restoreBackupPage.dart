import 'dart:convert';
import 'dart:io';
import 'package:SafeChat/pages/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart'; // For SHA-256 hashing
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

class RestoreBackupPage extends StatefulWidget {
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
      print("Backup Data: ${jsonEncode(encryptedData)}");


      String password = _passwordController.text.trim();
      if (password.isEmpty) {
        throw Exception("Password cannot be empty.");
      }

      // Attempt decryption
      Map<String, dynamic>  decryptedData = _decryptData(encryptedData, password);
      if (decryptedData.isEmpty) {
        throw Exception("Incorrect password or corrupted backup file.");
      }

      // Parse backup JSON
     // Map<String, dynamic> backupData = jsonDecode(decryptedData);

      // Restore Secure Storage Data
      await _restoreSecureStorage(decryptedData['keys']);

      if (decryptedData.containsKey('database') && decryptedData['database'] != null) {
        print("✅ Database backup found, restoring...");
        await _restoreDatabase(decryptedData['database'], password);
      } else {
        print("❌ No database found in backup data!");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backup restored successfully!")),
      );
      Navigator.push(context, MaterialPageRoute(
        builder: (context)=> HomePage(isLoggedIn: true),
      ));
    } catch (e) {
      print("Error restoring backup: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to restore backup: $e")),
      );
    }

    setState(() => _isRestoring = false);
  }
  /// **Decrypt Data Using AES-CBC**
  Map<String, dynamic> _decryptData(String encryptedData, String password) {
    try {
      print("🔍 Raw Encrypted Data: $encryptedData");

      final Map<String, dynamic> dataMap = jsonDecode(encryptedData);

      // ✅ Extract encrypted keys
      if (!dataMap.containsKey('keys')) {
        throw Exception('❌ Invalid backup file format: Missing keys.');
      }

      // ✅ Extract and decrypt keys
      final Map<String, dynamic> encryptedKeysMap = jsonDecode(dataMap['keys']);
      if (!encryptedKeysMap.containsKey('iv') || !encryptedKeysMap.containsKey('data')) {
        throw Exception('❌ Invalid encrypted keys format. Missing IV or Data.');
      }

      final iv = encrypt.IV.fromBase64(encryptedKeysMap['iv']);
      final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      String decryptedKeys = encrypter.decrypt64(encryptedKeysMap['data'], iv: iv);
      print("✅ Decrypted Keys: $decryptedKeys");

      // ✅ Extract and decode database
      String? encryptedDatabase = dataMap.containsKey('database') ? dataMap['database'] : null;
      if (encryptedDatabase != null && encryptedDatabase.isNotEmpty) {
        print("📦 Encrypted Database Found!");
      } else {
        print("❌ No database found in backup data.");
      }

      return {
        "keys": jsonDecode(decryptedKeys),
        "database": encryptedDatabase, // Base64-encoded, will decrypt later
      };
    } catch (e) {
      print('🔥 Decryption failed: $e');
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

        // // ✅ Verify by reading it back
        // String? storedValue = await _secureStorage.read(key: key);
        // print("Restored: $key -> $storedValue");
      }
    }
  }

  Future<void> _restoreDatabase(String encryptedDbBase64, String password) async {
    try {
      if (encryptedDbBase64.isEmpty) {
        throw Exception("❌ Database backup is missing or empty.");
      }

      print("🔐 Decoding & Decrypting Database...");

      // Decode Base64
      List<int> encryptedDbBytes = base64Decode(encryptedDbBase64);

      final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));

      // Extract IV (first 16 bytes)
      final ivBytes = encryptedDbBytes.sublist(0, 16);
      final encryptedBytes = encryptedDbBytes.sublist(16);

      final iv = encrypt.IV(Uint8List.fromList(ivBytes));
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      final decryptedDbBytes = encrypter.decryptBytes(
          encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
          iv: iv
      );
      // Check if decrypted data is valid
      print("📂 Decrypted Database Size: ${decryptedDbBytes.length} bytes");
      if (decryptedDbBytes.isEmpty) {
        throw Exception("❌ Decryption failed: Database file is empty after decryption.");
      }

      // Save Decrypted Database

      Directory externalDir = Directory("/storage/emulated/0/Download");
      String dbPath = await getDatabasesPath();
      final String currentUserID = _auth.currentUser!.uid;
      String fullDbPath = "$dbPath/user_database$currentUserID.db";

      print("🔍 Database Path: $fullDbPath");

      File dbFile = File(fullDbPath);
      if (await dbFile.exists()) {
        print("✅ Existing database found, overwriting...");
      } else {
        print("⚠️ No existing DB found, creating a new one.");
      }

      // Write to app database
      await dbFile.writeAsBytes(decryptedDbBytes, flush: true);
      print("✅ Database restored at: $fullDbPath");

      // Write to Downloads folder
      File dbFile1 = File('${externalDir.path}/user_database$currentUserID.db');
      await dbFile1.writeAsBytes(decryptedDbBytes, flush: true);
      print("📂 Copy saved to Downloads: ${dbFile1.path}");



      // Delete old database (to avoid conflicts)
      if (await dbFile.exists()) {
        await dbFile.delete();
        print("🗑 Old database deleted.");
      }

      await dbFile.writeAsBytes(decryptedDbBytes, flush: true);
      print("✅ Database Restored Successfully at: $dbPath");
      await dbFile.writeAsBytes(decryptedDbBytes, flush: true);


    } catch (e) {
      print("🔥 Database Restore Failed: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Restore Backup")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Enter Backup Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRestoring ? null : restoreBackup,
              child: _isRestoring
                  ? const CircularProgressIndicator()
                  : const Text("Restore Backup"),
            ),
          ],
        ),
      ),
    );
  }
}
