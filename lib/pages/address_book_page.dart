import 'dart:convert';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import '../components/user_tile.dart';
import '../crypto/X3DHHelper.dart';
import '../data/database_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';
class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key, required this.onEmailsChanged});

  final Function(List<String>) onEmailsChanged;

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

final AuthService authService = AuthService();
const FlutterSecureStorage storage = FlutterSecureStorage();
final x3dhHelper = X3DHHelper();


Uint8List decryptWithPrivateKey(String encryptedData, String privateKeyPem) {
  final parser = RSAKeyParser();
  final privateKey = parser.parse(privateKeyPem) as RSAPrivateKey;

  final cipher = RSAEngine()
    ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

  final decryptedBytes = cipher.process(base64Decode(encryptedData));
  return decryptedBytes;
}

class _AddressBookPageState extends State<AddressBookPage> {
  final TextEditingController _emailController = TextEditingController();
  List<String> _emails = [];

  @override
  void initState() {
    super.initState();
    _loadEmailsFromDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Address Book"),
      ),
      body: ListView.builder(
        itemCount: _emails.length,
        itemBuilder: (context, index) {
          return UserTile(
            text: _emails[index],
            onTap: () {
              _showOptionsBottomSheet(context, _emails[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showEmailInputDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEmailInputDialog(BuildContext context) {
    final TextEditingController nicknameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter Email Address and Nickname"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                String email = _emailController.text;
                String nickname = nicknameController.text;

                final userEmail = authService.getCurrentUser()?.email;
                String? userIdentityKeyBase64 = await storage.read(key: "identityKeyPairPublic$userEmail");
                String? userPreKeyBase64 = await storage.read(key: "preKeyPairPublic$userEmail");
                String? userPreKeyPrivateBase64 = await storage.read(key: "identityKeyPairPrivate$userEmail");

                print(email);
                print(userEmail);
                final userIdentityKey = base64Decode(userIdentityKeyBase64!);
                print("userIdentityKey: $userIdentityKey");
                final userPreKey = base64Decode(userPreKeyBase64!);
                print("userPreKey: $userPreKey");
                Uint8List privateKeyBytes = base64Decode(userPreKeyPrivateBase64!);
                String privateKeyPem = String.fromCharCodes(privateKeyBytes);



                HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('checkEmailExists');
                final response = await callable.call({'email': email});

                try {
                  if (response.data['exists']) {
                    print("Email exists in Firestore.");
                    print(email);
                    print(userEmail);
                    HttpsCallable retrieveKeysCallable = FirebaseFunctions.instance.httpsCallable('retrieveAliceKeys');
                    print("checking for pending messages....");
                    final retrieveKeysResponse = await retrieveKeysCallable.call({
                      'bobEmail': email,'aliceEmail':userEmail,
                    });
                    print('Response data: ${retrieveKeysResponse.data}');

                    print("completed");
                    print(retrieveKeysResponse.data['status']);
                    if (retrieveKeysResponse.data['status'] == 'No pending messages found for this user.') {
                      // Initiate X3DH
                      HttpsCallable initiateX3DHCallable = FirebaseFunctions.instance.httpsCallable('initiateX3DH');
                      final x3dhResponse = await initiateX3DHCallable.call({
                        'email': email,
                        'aliceEmail': '$userEmail',
                        'aliceIdentityKey': userIdentityKeyBase64,
                        'alicePreKey': userPreKeyBase64,
                      });
                      final data = x3dhResponse.data;
                      final String bobIdentityKey = data['bobIdentityKey'];
                      final bobPreKey = data['bobPreKey'];
                      final bobOneTimePreKey = data['bobOneTimePreKey'];
                      final index = data['index'];

                      // final decryptedPreKeyBytes = decryptWithPrivateKey(data['encryptedPreKey'], privateKeyPem);
                      // final decryptedPreKey = utf8.decode(decryptedPreKeyBytes);

                      // final decryptedOneTimePreKeyBytes = decryptWithPrivateKey(data['encryptedOneTimePreKey'], privateKeyPem);
                      // final decryptedOneTimePreKey = utf8.decode(decryptedOneTimePreKeyBytes);
                      print("performing X3DH...");
                      final x3dhResult = await x3dhHelper.performX3DHKeyAgreement(userEmail!,email,bobIdentityKey,bobOneTimePreKey,bobPreKey);
                      SecretKey sharedSecret = x3dhResult['sharedSecret'];
                      List<int> sharedSecretBytes = await sharedSecret.extractBytes();
                      print("Shared secret: $sharedSecretBytes");

                      await storage.write(
                          key: 'shared_Secret_With_${email}',
                          value: base64Encode(sharedSecretBytes));

                      print('Secret key generated and stored for $email.');
                    }

                    else if (retrieveKeysResponse.data['status'] =="yes") {
                      print("hi");
                      // final List<int> aliceIdentityKeyList = List<int>.from(retrieveKeysResponse.data['aliceIdentityKey']);
                      // final List<int> alicePreKeyList = List<int>.from(retrieveKeysResponse.data['alicePreKey']);
                      //
                      // print('Alice Identity Key List: $aliceIdentityKeyList');
                      // // print('Alice Pre Key List: $alicePreKeyList');
                      // final aliceIdentityKeyString = retrieveKeysResponse.data['aliceIdentityKey'] as String;
                      // final alicePreKeyString = retrieveKeysResponse.data['alicePreKey'] as String;
                      //
                      // final List<int> aliceIdentityKeyList = base64Decode(aliceIdentityKeyString);
                      // final List<int> alicePreKeyList = base64Decode(alicePreKeyString);
                      //
                      // // Create SimplePublicKey instances from the decoded bytes
                      // final aliceIdentityKey = SimplePublicKey(aliceIdentityKeyList, type: KeyPairType.x25519);
                      // final alicePreKey = SimplePublicKey(alicePreKeyList, type: KeyPairType.x25519);


                      final int indexOTPK = retrieveKeysResponse.data['index'];
                      print("performing x3dh for bob ....");
                      final x3dhResult = await x3dhHelper.performX3DHKeyAgreementForBob(userEmail!, email,retrieveKeysResponse.data);
                      print("object");
                      SecretKey sharedSecret = x3dhResult['sharedSecret'];
                      List<int> sharedSecretBytes = await sharedSecret.extractBytes();
                      await storage.write(key: 'shared_Secret_With_$email', value: base64Encode(sharedSecretBytes));
                      print("Shared secret: $sharedSecretBytes");
                      final storedSecretKeyString = await storage.read(key: 'shared_Secret_With_${email}');
                      print(storedSecretKeyString);
                    }
                    else {
                      print("oh no...");
                    }



                    setState(() {
                      _emails.add(nickname); // Add the nickname to the list
                      _saveEmailToDatabase(email, nickname); // Save email with nickname

                    });
                  } else {
                    print("Email does not exist.");
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Email address does not exist.'),
                    ));
                  }
                  _emailController.clear(); // Clear the text field
                  nicknameController.clear(); // Clear the nickname field
                  Navigator.of(context).pop(); // Close the dialog
                } catch (e) {
                  print("Error checking email: $e");
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showOptionsBottomSheet(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Update'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  _showUpdateDialog(context, email);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet
                  deleteEmail(email); // Await the deletion operation
                  _loadEmailsFromDatabase(); // Reload emails after deletion
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateDialog(BuildContext context, String oldEmail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController newEmailController = TextEditingController();
        return AlertDialog(
          title: const Text("Update Email Address"),
          content: TextField(
            controller: newEmailController,
            decoration: InputDecoration(labelText: 'New Email Address', hintText: oldEmail),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                //_updateEmail(oldEmail, _newEmailController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void deleteEmail(String email) async {
    await DatabaseHelper.instance.deleteEmail(email);
    _loadEmailsFromDatabase();
    widget.onEmailsChanged(_emails); // Notify the parent widget about the updated emails
  }

  void _loadEmailsFromDatabase() async {
    List<Map<String, dynamic>> emailNicknames = await DatabaseHelper.instance.queryAllEmailsWithNicknames();
    setState(() {
      _emails = emailNicknames.map((entry) => entry['nickname'] ?? entry['email']).cast<String>().toList();
    });
    widget.onEmailsChanged(_emails); // Notify the parent widget about the updated emails
  }


  void _saveEmailToDatabase(String email, String nickname) async {
    await DatabaseHelper.instance.insertEmail(email, nickname);
    _loadEmailsFromDatabase();
    widget.onEmailsChanged(_emails); // Notify the parent widget about the updated emails
  }
}
