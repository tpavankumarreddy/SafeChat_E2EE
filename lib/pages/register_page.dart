import 'dart:async';
import 'package:email_validator/email_validator.dart';
import 'package:emailchat/services/auth/auth_service.dart';
import 'package:emailchat/components/my_button.dart';
import 'package:emailchat/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import '../services/auth/otp_service.dart';
import 'otp_page.dart';

class RegisterPage extends StatelessWidget {
  EmailOTP myAuth = EmailOTP();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();

  final void Function()? onTap;

  RegisterPage({super.key, required this.onTap});

  // Timer related fields
  Timer? _timer;
  int _remainingTime = 90;
  bool _showResendButton = false;

  Future<void> _startTimer(VoidCallback onResendAvailable) async {
    _remainingTime = 90; // reset timer to 90 sec
    _showResendButton = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        _remainingTime--;
      } else {
        _showResendButton = true;
        timer.cancel();
        onResendAvailable();
      }
    });
  }

  Future<void> _resendOTP() async {
    _startTimer(() {});
    await OTPService().sendOTP(myAuth, _emailController.text, _nameController.text);
  }

  Future<void> register(BuildContext context) async {

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _pwController.text.isEmpty ||
        _confirmPwController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("All fields are required.", style: TextStyle(fontSize: 16)),
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
      return;
    }

    if (!EmailValidator.validate(_emailController.text)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Enter a valid email address.", style: TextStyle(fontSize: 16)),
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
      return;
    }

    if (_pwController.text == _confirmPwController.text && _pwController.text.length >= 6) {

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPPage(
            email: _emailController.text,
            username: _nameController.text,
            onOTPVerified: () async {
              final auth = AuthService();
              try {
                final returnedOTP = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OTPPage(
                      email: _emailController.text,
                      username: _nameController.text,
                      onOTPVerified: () {},
                    ),
                  ),
                );

                if (returnedOTP != null) {
                  try {
                  await auth.signUpWithEmailPassword(_emailController.text, _pwController.text, returnedOTP);

                  Navigator.pop(context); // Navigate back to RegisterPage
                  showDialog(
                    context: context,
                    builder: (context) => const SnackBar(
                      content: Text("Registration Successful! 🥳. Your account has been created."),
                  ),
                );
                } on Exception catch (e) {
                    if (e.toString().contains('email-already-in-use')) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Email already in use"),
                          content: const Text("This email is already registered. Please login instead."),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Dismiss the dialog
                                onTap?.call(); // Navigate to login page
                              },
                              child: const Text('Login'),
                            ),
                          ],
                        ),
                      );
                    }
                    else {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Registration Error"),
                          content: Text(e.toString()),
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
              }
              }catch (e) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(e.toString()),
                  ),
                );
              }
            },
          ),
        ),
      );

    } else if (_pwController.text != _confirmPwController.text) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Passwords don't match", style: TextStyle(fontSize: 18)),
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
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Password length should be at least 6.", style: TextStyle(fontSize: 18)),
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
            Icon(
              Icons.message,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 50),
            Text(
              "Hello, let's get you registered.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 50),
            MyTextField(
              hintText: "Name",
              obscuredText: false,
              controller: _nameController,
            ),
            const SizedBox(height: 10),
            MyTextField(
              hintText: "Email",
              obscuredText: false,
              controller: _emailController,
            ),
            const SizedBox(height: 10),
            MyTextField(
              hintText: "Password",
              obscuredText: true,
              controller: _pwController,
            ),
            const SizedBox(height: 10),
            MyTextField(
              hintText: "Confirm Password",
              obscuredText: true,
              controller: _confirmPwController,
            ),
            const SizedBox(height: 25),
            MyButton(
              text: "R E G I S T E R",
              onTap: () => register(context),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                GestureDetector(
                  onTap: onTap,
                  child: const Text(
                    "Login Now!!",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
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
