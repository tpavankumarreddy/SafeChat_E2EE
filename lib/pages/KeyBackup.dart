import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class KeyBackupManager extends StatefulWidget {
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
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_passwordController.text.isNotEmpty) {
                  await _secureStorage.write(
                      key: 'backupPassword', value: _passwordController.text);
                  Navigator.pop(context);
                  final String currentUserEmail = _auth.currentUser!.email!;
                  _passwordController.clear();
                  _backupData(currentUserEmail); // Call backup after confirming password
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

  Future<void> _backupData(String email) async {
    String? password = await _secureStorage.read(key: 'backupPassword');
    if (password == null || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Backup password is missing!")),
      );
      return;
    }

    final String currentUserID = _auth.currentUser!.uid;

    String dbPath = await getDatabasesPath();
    String dbPath1 = '${dbPath}/user_database$currentUserID.db';

    // 🔹 Open Database
    Database db = await openDatabase(dbPath1);

    // 1. Backup Keys
    Map<String, String> keyData = await _backupKeys(email,db);

    // 2. Backup SQLite Database
    File? databaseFile = await _backupDatabase();

    // 3. Convert keys to JSON
    String jsonData = jsonEncode(keyData);

    // 4. Encrypt keys and database
    String encryptedKeys = _encryptData(jsonData, password);
    List<int>? encryptedDbBytes;
    if (databaseFile != null) {
      encryptedDbBytes = _encryptDatabase(await databaseFile.readAsBytes(), password);
    }


    await _saveToFile(email, encryptedKeys, encryptedDbBytes);
  }

  Future<Map<String, String>> _backupKeys(String email, Database db) async {
    Map<String, String> keyData = {};

    // 🔹 Load Identity & Prekeys
    keyData['identityKeyPairPrivate'] =
        await _secureStorage.read(key: 'identityKeyPairPrivate$email') ?? '';
    keyData['identityKeyPairPublic'] =
        await _secureStorage.read(key: 'identityKeyPairPublic$email') ?? '';
    keyData['preKeyPairPrivate'] =
        await _secureStorage.read(key: 'preKeyPairPrivate$email') ?? '';
    keyData['preKeyPairPublic'] =
        await _secureStorage.read(key: 'preKeyPairPublic$email') ?? '';

    // 🔹 Load One-Time Prekeys
    int i = 0;
    while (true) {
      String? privateKey = await _secureStorage.read(key: 'oneTimePreKeyPairPrivate$email$i');
      String? publicKey = await _secureStorage.read(key: 'oneTimePreKeyPairPublic$email$i');
      if (privateKey == null || publicKey == null) break;
      keyData['oneTimePreKeyPairPrivate$i'] = privateKey;
      keyData['oneTimePreKeyPairPublic$i'] = publicKey;
      i++;
    }

    // 🔹 Fetch all emails from user_data table
    List<Map<String, dynamic>> userList = await db.query('user_data', columns: ['email']);
    List<String> emails = userList.map((row) => row['email'] as String).toList();

    // 🔹 Load Shared Secrets for Each Email
    for (String userEmail in emails) {
      String? sharedSecret = await _secureStorage.read(key: 'shared_Secret_With_$userEmail');
      if (sharedSecret != null) {
        keyData['sharedSecret_$userEmail'] = sharedSecret;
      }
    }

    // 🔹 Fetch all group IDs from group_data table
    List<Map<String, dynamic>> groupList = await db.query('group_data', columns: ['groupId']);
    List<String> groupIds = groupList.map((row) => row['groupId'] as String).toList();

    // 🔹 Load Group Secret Keys
    for (String groupId in groupIds) {
      String? groupSecret = await _secureStorage.read(key: 'group_secret_key_$groupId');
      if (groupSecret != null) {
        keyData['groupSecret_$groupId'] = groupSecret;
      }
    }
    print("Backup Data: $keyData");
    await db.close();
    return keyData;
  }




  Future<File?> _backupDatabase() async {
    try {
      String dbPath = await getDatabasesPath();
      final String currentUserID = _auth.currentUser!.uid;
      File originalDb = File("$dbPath/user_database$currentUserID.db"); // Change to your database name
      if (await originalDb.exists()) {
        Directory backupDir = await getApplicationDocumentsDirectory();
        File backupDb = File("${backupDir.path}/safechat_backup.db");
        await originalDb.copy(backupDb.path);
        return backupDb;
      } else {
        print("Database file not found.");
        return null;
      }
    } catch (e) {
      print("Database backup failed: $e");
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

    return encrypted.bytes;
  }

  Future<void> _saveToFile(String email, String encryptedKeys, List<int>? encryptedDbBytes) async {
    Directory externalDir = Directory("/storage/emulated/0/Download"); // Default Downloads folder
    File backupFile = File('${externalDir.path}/backup_$email.enc');

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
        title: const Text("Backup Keys"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This backup will include your public and private keys, "
                  "individual chat keys with each users and group keys for "
                  "each group you joined and all the databases. "
                  "This backup will be stored in an encrypted file. "
                  "You will need to set a password to secure the backup."
                  "And you need to remember this password for using this backup.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _promptForPassword,
                child: const Text("Backup Now"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
