import 'dart:convert';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as path;
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../components/user_tile.dart';
import '../crypto/KeyUtility.dart';
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
    ..init(false, pc.PrivateKeyParameter<RSAPrivateKey>(privateKey));

  final decryptedBytes = cipher.process(base64Decode(encryptedData));
  return decryptedBytes;
}
void showQrDialog(BuildContext context) {
  final userEmail = authService.getCurrentUser()?.email ?? "Unknown User";
  final qrData = jsonEncode({'email': userEmail});

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Your QR Code'),
        content: SizedBox(
          width: 200, // Define a fixed width
          height: 200, // Define a fixed height
          child: Center(
            child: qrData.isNotEmpty
                ? QrImageView(
              data: qrData, // Data for QR code
              version: QrVersions.auto,
              size: 200.0, // Explicit size for QR code
            )
                : const CircularProgressIndicator(), // Show a loading spinner if QR data is not ready
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}







class _AddressBookPageState extends State<AddressBookPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();

  List<String> _emails = [];

  void _scanQrCode(BuildContext context) async {
    bool isProcessing = false; // Add a flag to prevent multiple calls

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Scan QR Code')),
          body: Center(
            child: SizedBox(
              width: 300, // Restrict width
              height: 400, // Restrict height
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    onDetect: (capture) async {
                      if (isProcessing) return; // Prevent duplicate processing
                      isProcessing = true;

                      final List<Barcode> barcodes = capture.barcodes;
                      final Barcode? barcode =
                      barcodes.isNotEmpty ? barcodes.first : null;

                      if (barcode != null && barcode.rawValue != null) {
                        final scannedData = jsonDecode(barcode.rawValue!);
                        final scannedEmail = scannedData['email'];

                        // Show a circular progress indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        );

                        try {
                          // Check if the email already exists in the list
                          if (!_emails.contains(scannedEmail)) {
                            // Perform key retrieval and exchange
                            await performKeyRetrivalAndExchange(
                                scannedEmail, scannedEmail);

                            // Add to the list and save to the database
                            if (mounted) {
                              setState(() {
                                _emails.add(scannedEmail);
                                _saveEmailToDatabase(scannedEmail, scannedEmail);
                              });
                            }

                            // Show a success message
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'The email "$scannedEmail" has been added to your address book.'),
                                ),
                              );
                            }
                          } else {
                            // Show a message if the email already exists
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'The email "$scannedEmail" is already in your address book.'),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Handle errors
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Error processing QR code. Please try again.'),
                              ),
                            );
                          }
                        } finally {
                          // Close the progress indicator and scanner screen
                          if (mounted) {
                            Navigator.pop(context); // Close the progress dialog
                            Navigator.pop(context); // Close the scanner screen
                          }
                          isProcessing = false; // Reset the flag
                        }
                      } else {
                        isProcessing = false; // Reset the flag if no valid barcode
                      }
                    },
                  ),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }




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
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: const Text('Show QR Code'),
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      showQrDialog(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner),
                    title: const Text('Scan QR Code'),
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      _scanQrCode(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Contact Manually'),
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      _showEmailInputDialog(context);
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),

    );
  }


  void _showEmailInputDialog(BuildContext context) {
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
                // Show a loading dialog while processing
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(
                      child: Dialog(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('Processing, please wait...'),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );

                bool success = await performKeyRetrivalAndExchange(
                  _emailController.text,
                  nicknameController.text,
                );

                if (!mounted) return; // Check if widget is still mounted

                Navigator.pop(context); // Dismiss the loading dialog

                if (success) {
                  setState(() {
                    _emails.add(nicknameController.text); // Add the nickname to the list
                    _saveEmailToDatabase(
                      _emailController.text,
                      nicknameController.text,
                    ); // Save email with nickname
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to process email. Please try again.'),
                    ),
                  );
                }
                Navigator.pop(context); // Close the email input dialog
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
  Future<bool> performKeyRetrivalAndExchange(String email, String nickname ) async {

    try {
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
            print("performing X3DH...");
            final x3dhResult = await x3dhHelper.performX3DHKeyAgreement(userEmail!,email,bobIdentityKey,bobOneTimePreKey,bobPreKey);
            SecretKey sharedSecret = x3dhResult['sharedSecret'];
            List<int> sharedSecretBytes = await sharedSecret.extractBytes();
            print("Shared secret: $sharedSecretBytes");

            await storage.write(
                key: 'shared_Secret_With_${email}',
                value: base64Encode(sharedSecretBytes));

            print('Secret key generated and stored for $email.');
            try {
              Map<String, Uint8List> keys = await KeyUtility.deriveKeys(email);
              print('Derived Keys: ${keys.map((key, value) => MapEntry(key, base64Encode(value)))}');
            } catch (e) {
              print('Error: $e');
            }

            try {
              // Derive keys using KeyUtility
              Map<String, Uint8List> derivedKeys = await KeyUtility.deriveKeys(email);

              // Store each derived key in secure storage with the respective algorithm name
              for (var entry in derivedKeys.entries) {
                final algorithmName = entry.key;
                final derivedKey = entry.value;
                await storage.write(
                  key: 'shared_Secret_With_${email}_$algorithmName',
                  value: base64Encode(derivedKey),
                );
                print('Derived key for $algorithmName stored for $email.');
              }
            } catch (e) {
              print('Error during key derivation or storage: $e');
            }
          }

          else if (retrieveKeysResponse.data['status'] =="yes") {
            print("hi");
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

            try {
              Map<String, Uint8List> keys = await KeyUtility.deriveKeys(email);
              print('Derived Keys: ${keys.map((key, value) => MapEntry(key, base64Encode(value)))}');
            } catch (e) {
              print('Error: $e');
            }

            try {
              // Derive keys using KeyUtility
              Map<String, Uint8List> derivedKeys = await KeyUtility.deriveKeys(email);

              // Store each derived key in secure storage with the respective algorithm name
              for (var entry in derivedKeys.entries) {
                final algorithmName = entry.key;
                final derivedKey = entry.value;
                await storage.write(
                  key: 'shared_Secret_With_${email}_$algorithmName',
                  value: base64Encode(derivedKey),
                );
                print('Derived key for $algorithmName stored for $email.');
              }
            } catch (e) {
              print('Error during key derivation or storage: $e');
            }


          }
          else {
            print("oh no...");
          }


         // Navigator.of(context as BuildContext).pop();

          print("object");


          return true;

        } else {
          Navigator.of(context as BuildContext).pop();
          print("Email does not exist.");
          ScaffoldMessenger.of(context as BuildContext).showSnackBar(const SnackBar(
            content: Text('Email address does not exist.'),
          ));
        }
        _emailController.clear(); // Clear the text field
        nicknameController.clear(); // Clear the nickname field
        //Navigator.of(context as BuildContext).pop(); // Close the dialog
        return false;
      } catch (e) {
        //Navigator.of(context as BuildContext).pop();
        print("Error checking email: $e");
        return false;
      }
    } catch (e) {
      print("Error during key retrieval and exchange: $e");
      return false;
    }
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
    await DatabaseHelper.instance.deleteByEmailOrNickname(email);
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
