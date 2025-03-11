import 'dart:convert';
import 'dart:io';
import 'package:SafeChat/pages/restoreBackupPage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class KeyBackupManager extends StatefulWidget {
  const KeyBackupManager({super.key});

  @override
  _KeyBackupManagerState createState() => _KeyBackupManagerState();
}

class _KeyBackupManagerState extends State<KeyBackupManager> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _promptForPassword() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Encryption Password"),
          content: TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_passwordController.text.isNotEmpty) {
                  await _secureStorage.write(
                      key: 'backupPassword', value: _passwordController.text);
                  Navigator.pop(context);
                  _passwordController.clear();
                  _backupData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Password cannot be empty")),
                  );
                }
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _backupData() async {
    String? password = await _secureStorage.read(key: 'backupPassword');
    if (password == null || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backup password is missing!")),
      );
      return;
    }

    final String currentUserID = _auth.currentUser!.uid;
    final String? currentUserEmail = _auth.currentUser!.email;

    String dbPath = await getDatabasesPath();
    String dbFilePath = '$dbPath/user_database$currentUserID.db';

    Database db = await openDatabase(dbFilePath);
    Map<String, String> keyData = await _backupKeys(currentUserEmail!,db);
    File? databaseFile = await _backupDatabase();

    String jsonData = jsonEncode(keyData);
    String encryptedKeys = _encryptData(jsonData, password);
    List<int>? encryptedDbBytes = databaseFile != null
        ? _encryptDatabase(await databaseFile.readAsBytes(), password)
        : null;

    await _saveToFile(encryptedKeys, encryptedDbBytes);
  }

  Future<Map<String, String>> _backupKeys(String email, Database db) async {
    Map<String, String> keyData = {};

    // 🔹 Load Identity & Prekeys
    keyData['identityKeyPairPrivate$email'] =
        await _secureStorage.read(key: 'identityKeyPairPrivate$email') ?? '';
    keyData['identityKeyPairPublic$email'] =
        await _secureStorage.read(key: 'identityKeyPairPublic$email') ?? '';
    keyData['preKeyPairPrivate$email'] =
        await _secureStorage.read(key: 'preKeyPairPrivate$email') ?? '';
    keyData['preKeyPairPublic$email'] =
        await _secureStorage.read(key: 'preKeyPairPublic$email') ?? '';

    // 🔹 Load One-Time Prekeys
    int i = 0;
    while (true) {
      String? privateKey = await _secureStorage.read(key: 'oneTimePreKeyPairPrivate$email$i');
      String? publicKey = await _secureStorage.read(key: 'oneTimePreKeyPairPublic$email$i');
      if (privateKey == null || publicKey == null) break;
      keyData['oneTimePreKeyPairPrivate$email$i'] = privateKey;
      keyData['oneTimePreKeyPairPublic$email$i'] = publicKey;
      i++;
    }

    // 🔹 Fetch all emails from user_data table
    List<Map<String, dynamic>> userList = await db.query('user_data', columns: ['email']);
    List<String> emails = userList.map((row) => row['email'] as String).toList();

    // 🔹 Load Shared Secrets for Each Email
    for (String userEmail in emails) {
      String? sharedSecret = await _secureStorage.read(key: 'shared_Secret_With_$userEmail');
      if (sharedSecret != null) {
        keyData['shared_Secret_With_$userEmail'] = sharedSecret;
      }
    }

    // 🔹 Fetch all group IDs from group_data table
    List<Map<String, dynamic>> groupList = await db.query('group_data', columns: ['groupId']);
    List<String> groupIds = groupList.map((row) => row['groupId'] as String).toList();

    // 🔹 Load Group Secret Keys
    for (String groupId in groupIds) {
      String? groupSecret = await _secureStorage.read(key: 'group_secret_key_$groupId');
      if (groupSecret != null) {
        keyData['group_secret_key_$groupId'] = groupSecret;
      }
    }
    print("Backup Data: $keyData");
    return keyData;
  }

  Future<File?> _backupDatabase() async {
    try {
      String dbPath = await getDatabasesPath();
      final String currentUserID = _auth.currentUser!.uid;
      File originalDb = File("$dbPath/user_database$currentUserID.db");
      if (!await originalDb.exists()) return null;
      Directory backupDir = await getApplicationDocumentsDirectory();
      File backupDb = File("${backupDir.path}/safechat_backup.db");
      await originalDb.copy(backupDb.path);
      return backupDb;
    } catch (e) {
      return null;
    }
  }

  String _encryptData(String data, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(data, iv: iv);
    return jsonEncode({'iv': base64Encode(iv.bytes), 'data': encrypted.base64});
  }

  List<int> _encryptDatabase(List<int> dbBytes, String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, '0'));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(dbBytes, iv: iv);
    return iv.bytes + encrypted.bytes;
  }

  Future<void> _saveToFile(String encryptedKeys, List<int>? encryptedDbBytes) async {
    final String currentUserEmail = _auth.currentUser!.email!;
    Directory externalDir = Directory("/storage/emulated/0/Download");
    File backupFile = File('${externalDir.path}/SafeChat_Backup_$currentUserEmail.enc');
    Map<String, dynamic> backupData = {
      "keys": encryptedKeys,
      "database": encryptedDbBytes != null ? base64Encode(encryptedDbBytes) : null,
    };
    await backupFile.writeAsString(jsonEncode(backupData));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Backup saved to: ${backupFile.path}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Backup and Restore Data"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This backup includes your encryption keys and database. Ensure you remember your password.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _promptForPassword,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Backup Now"),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RestoreBackupPage())),
                child: const Text('Restore from Backup'),
              ),
            ),

          ],
        ),
      ),
    );
  }
}