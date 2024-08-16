
import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../components/my_button.dart';
import '../components/my_textfield.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/otp_service.dart';

// Password strength checker class
class PasswordStrength {
  static Map<String, String> checkPasswordStrength(String password) {
    List<String> issues = [];

    // Check password length
    if (password.length < 8) {
      issues.add("Password should be at least 8 characters long.");
    }

    // Check for uppercase letters
    if (!password.contains(RegExp(r'[A-Z]'))) {
      issues.add("Password should contain at least one uppercase letter.");
    }

    // Check for lowercase letters
    if (!password.contains(RegExp(r'[a-z]'))) {
      issues.add("Password should contain at least one lowercase letter.");
    }

    // Check for digits
    if (!password.contains(RegExp(r'\d'))) {
      issues.add("Password should contain at least one number.");
    }

    // Check for special characters
    if (!password.contains(RegExp(r'[!@#\$&*~%^(){};:<>?/|,.\[\]_=+\\-]'))) {
      issues.add("Password should contain at least one special character (e.g., @, #, \$).");
    }

    // Assign a score based on the password quality
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'\d'))) score++;
    if (password.contains(RegExp(r'[!@#\$&*~%^(){};:<>?/|,.\[\]_=+\\-]'))) score++;
    if (password.length > 12) score++;

    String strength = "";

    switch (score) {
      case 0:
      case 1:
        strength = "Very Weak";
        break;
      case 2:
        strength = "Weak";
        break;
      case 3:
        strength = "Moderate";
        break;
      case 4:
        strength = "Strong";
        break;
      case 5:
        strength = "Very Strong";
        break;
      default:
        strength = "Invalid";
    }

    if (issues.isEmpty) {
      issues.add("Your password is strong enough.");
    }

    return {
      'strength': strength,
      'details': issues.join('\n'),
    };
  }
}

class RegisterPage extends StatelessWidget {
  EmailOTP myAuth = EmailOTP();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final void Function()? onTap;

  RegisterPage({super.key, required this.onTap});

  // Register method
  Future<void> register(BuildContext context) async {
    final auth = AuthService();
    final otpService = OTPService();

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

    // Check password strength and get feedback
    Map<String, String> passwordFeedback = PasswordStrength.checkPasswordStrength(_pwController.text);
    String passwordStrength = passwordFeedback['strength']!;
    String passwordDetails = passwordFeedback['details']!;

    if (passwordStrength == "Very Weak" || passwordStrength == "Weak") {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Password is too weak. Strength: $passwordStrength", style: const TextStyle(fontSize: 18)),
          content: Text(passwordDetails),
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
      try {
        await otpService.sendOTP(myAuth, _emailController.text, _nameController.text);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Enter OTP'),
              content: TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'OTP'),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final otp = _otpController.text;
                    if (await EmailOTP.verifyOTP(otp: otp)) {
                      print("OTP is verified");
                      await auth.signUpWithEmailPassword(_emailController.text, _pwController.text, otp);
                      Navigator.pop(context);
                    } else {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Invalid OTP", style: TextStyle(fontSize: 18)),
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
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(e.toString()),
          ),
        );
      }
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

  // Google Sign-In method (remains unchanged)

  // Helper methods (unchanged)

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
              text: "Register",
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
