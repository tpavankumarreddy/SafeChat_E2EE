import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/components/my_button.dart';
import 'package:SafeChat/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;

  LoginPage({Key? key, required this.onTap}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for email and password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // State for controlling password visibility
  bool _isObscured = true;

  // Login method
  void login(BuildContext context) async {
    final authService = AuthService();

    // Try login
    try {
      await authService.signInWithEmailPassword(
          _emailController.text, _pwController.text);
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

  // Sign in with Google method
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
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
              Icons.security,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),

            const SizedBox(height: 50),

            // Welcome text
            Text(
              "Welcome to SafeChat",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            Text(
              "Let's get started.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 15),

            // Email TextField
            MyTextField(
              hintText: "Email",
              obscuredText: false,
              controller: _emailController,
              onChanged: (value) {},
            ),

            const SizedBox(height: 10),

            // Password TextField with visibility toggle aligned 2cm to the left
            Stack(
              alignment: Alignment.centerRight,
              children: [
                MyTextField(
                  hintText: "Password",
                  obscuredText: _isObscured,
                  controller: _pwController,
                  onChanged: (value) {},
                ),
                Positioned(
                  right: 20.0, // Approximately 2 cm (60 pixels)
                  child: IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Login button
            MyButton(
              text: "L O G I N",
              onTap: () => login(context),
              fontSize: 18,
            ),

            const SizedBox(height: 20),

            // Sign in with Google button
            SignInButton(
              Buttons.Google,
              text: "Sign in with Google",
              onPressed: () => signInWithGoogle(context),
            ),

            const SizedBox(height: 20),

            // Register prompt
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Not a member? "),
                GestureDetector(
                  onTap: widget.onTap,
                  child: const Text(
                    "Register now!!",
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
