import 'package:emailchat/services/auth/auth_service.dart';
import 'package:emailchat/components/my_button.dart';
import 'package:emailchat/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatelessWidget{

  //email, pw controllers
  final TextEditingController _emailController=TextEditingController();
  final TextEditingController _pwController=TextEditingController();

  final void Function()? onTap;


 LoginPage({super.key, required this.onTap});

 //login method
  void login(BuildContext context) async {
    // auth service
    final authService = AuthService();

    //try login
    try {
      await authService.signInWithEmailPassword(_emailController.text, _pwController.text);

    }

    //catch errors
    catch (e) {
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
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
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
          //logo
          Icon(Icons.security,
          size : 80,
          color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: 50),
          //welcome back
          Text("Welcome to SafeChat ",
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize:20,
            fontWeight: FontWeight.bold,
          ),
          ),

          const SizedBox(height: 30),


          Text("Let's get started.",

            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize:20,
            ),
          ),
          const SizedBox(height: 15),

          //email

          MyTextField(
            hintText: "Email",
            obscuredText: false,
            controller: _emailController,
          ),

          const SizedBox(height: 10),
          //pw

          MyTextField(
            hintText: "Password",
            obscuredText: true,
            controller: _pwController,
          ),

          const SizedBox(height: 20),

          //login

          MyButton(
            text: "Login",
            onTap: () => login(context),
            fontSize: 16,
          ),

          const SizedBox(height: 20),
          SignInButton(
            Buttons.Google,
            text: "Sign in with Google",
            onPressed: () => signInWithGoogle(context),
          ),

          const SizedBox(height: 20),
          //register
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Not a member? "),
            GestureDetector(
              onTap: onTap,
              child: const Text("Register now!!",
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