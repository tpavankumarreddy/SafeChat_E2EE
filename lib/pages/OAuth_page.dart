import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login_page.dart';

class OAuthPage extends StatefulWidget {
  final void Function()? onTap;

  OAuthPage({Key? key, required this.onTap}) : super(key: key);

  @override
  _OAuthPageState createState() => _OAuthPageState();
}

class _OAuthPageState extends State<OAuthPage> {
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
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google OAuth registration successful!')),
      );
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

  // Sign in with GitHub method
  Future<void> signInWithGitHub(BuildContext context) async {
    try {
      final AuthCredential credential = GithubAuthProvider.credential('your-github-token');

      // Sign in with Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub OAuth registration successful!')),
      );
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
              "OAuth Verification",
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

            // Google Sign-In button
            ElevatedButton(
              onPressed: _isButtonEnabled ? () => signInWithGoogle(context) : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: _isButtonEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Register with Google"),
            ),

            const SizedBox(height: 10),

            // GitHub Sign-In button
            ElevatedButton(
              onPressed: _isButtonEnabled ? () => signInWithGitHub(context) : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                backgroundColor: _isButtonEnabled
                    ? Colors.black
                    : Colors.grey,
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: const Text("Register with GitHub"),
            ),

            const SizedBox(height: 20),

            //Login Page
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already a member? "),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginPage(onTap: () { LoginPage; },), // Redirect to login page
                      ),
                    );
                  }, // Redirect to login page
                  child: const Text(
                    "Login now!",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
