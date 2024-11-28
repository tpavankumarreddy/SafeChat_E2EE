import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../crypto/key_gen.dart';
import 'login_page.dart';

class OAuthPage extends StatefulWidget {
  final void Function()? onTap;

  OAuthPage({Key? key, required this.onTap}) : super(key: key);

  @override
  _OAuthPageState createState() => _OAuthPageState();
}

class _OAuthPageState extends State<OAuthPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController _pinController = TextEditingController();
  bool _isButtonEnabled = false;

  // Validate the 6-digit PIN
  void _checkPinValidity(String value) {
    if (value.length == 6 && RegExp(r'^\d{6}$').hasMatch(value)) {
      setState(() {
        _isButtonEnabled = true;
      });
    } else {
      setState(() {
        _isButtonEnabled = false;
      });
    }
  }

  // Sign in with Google method
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled the sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      print("object");
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Access the signed-in user's information
      User? user = userCredential.user;
      if (true){
        showDialog(
            context: context,
            barrierDismissible: false, // Prevents dialog from being dismissed
            builder: (BuildContext context) {
              return const Dialog(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Please wait, your keys are being generated...'),
                    ],
                  ),
                ),
              );
            },
        );
      }
      await firestore.collection("user's").doc(userCredential.user!.uid).set({
        'uid': user!.uid,
        'email': user.email.toString(),
      });

      print("object1");



      if (user != null) {
        await KeyGenerator().generateAndStoreKeys(user.uid, user.email.toString(), _pinController.text);
      } else {
        print('No user was returned.');
      }

      // Generate and store keys

      print("object2");
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google OAuth registration successful!')),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Registration Successful! 🥳 Your account has been created."),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);



    } catch (e) {
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(e.toString(), style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    }
  }



  // Navigate to login page (existing one)
  void _navigateToLoginPage() {
    if (widget.onTap != null) {
      widget.onTap!(); // Call the provided onTap callback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Icon(
              Icons.lock,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),

            const SizedBox(height: 50),

            // Welcome text
            Text(
              "OAuth Registration",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // Enter 6-digit PIN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: "Enter a random 6-digit code",
                  counterText: "", // Remove counter
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _checkPinValidity,
              ),
            ),

            const SizedBox(height: 20),

            // Google Sign-In buttons
            ElevatedButton(
              onPressed: _isButtonEnabled ? () => signInWithGoogle(context) : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: _isButtonEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                textStyle: const TextStyle(fontSize: 18),
              ).copyWith(
                foregroundColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                    return _isButtonEnabled ? Colors.white : Colors.black;
                  },
                ),
              ),
              child: const Text("Register with Google"),
            )
,

            const SizedBox(height: 20),



          ],
        ),
      ),
    );
  }
}
