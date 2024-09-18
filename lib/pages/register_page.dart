import 'dart:async';
import 'package:email_validator/email_validator.dart';
import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/components/my_button.dart';
import 'package:SafeChat/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import '../services/auth/otp_service.dart';
import 'login_page.dart';
import 'otp_page.dart';
import 'OAuth_page.dart'; // Import OAuth page

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;

  const RegisterPage({Key? key, required this.onTap}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final EmailOTP myAuth = EmailOTP();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Timer related fields
  Timer? _timer;
  int _remainingTime = 90;
  bool _showResendButton = false;

  // State to manage whether password is obscured or not
  bool _isObscured = true;
  bool _isConfirmObscured = true;

  // Regular expression to check if string
  final RegExp passValid = RegExp(r"(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*\W)");
  double passwordStrength = 0;

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

  // A function that validates the user-entered password
  bool validatePassword(String pass) {
    String password = pass.trim();

    if (password.isEmpty) {
      setState(() {
        passwordStrength = 0;
      });
    } else if (password.length < 6) {
      setState(() {
        passwordStrength = 1 / 4;
      });
    } else if (password.length < 8) {
      setState(() {
        passwordStrength = 2 / 4;
      });
    } else {
      if (passValid.hasMatch(password)) {
        setState(() {
          passwordStrength = 4 / 4;
        });
        return true;
      } else {
        setState(() {
          passwordStrength = 3 / 4;
        });
        return false;
      }
    }
    return false;
  }

  Future<void> register(BuildContext context) async {
    String? returnedOTP;

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

    if (_pwController.text == _confirmPwController.text && validatePassword(_pwController.text)) {
      returnedOTP = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPPage(
            email: _emailController.text,
            username: _nameController.text,
            password: _pwController.text,
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
          title: const Text(
            "Password should contain Capital, small letter & Number & Special",
            style: TextStyle(fontSize: 18),
          ),
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
        child: Form(
          key: _formKey,
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
                onChanged: (value) {},
              ),
              const SizedBox(height: 10),
              MyTextField(
                hintText: "Email",
                obscuredText: false,
                controller: _emailController,
                onChanged: (value) {},
              ),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  MyTextField(
                    hintText: "Password",
                    obscuredText: _isObscured,
                    controller: _pwController,
                    onChanged: (value) {
                      setState(() {
                        validatePassword(value); // Validate password in real-time
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20), // Adjust the padding here (5 pixels ~ 0.5 cm)
                    child: IconButton(
                      icon: Icon(
                        _isObscured ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured; // Toggle Visibility
                        });
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: passwordStrength,
                      backgroundColor: Colors.grey[300],
                      minHeight: 5,
                      color: passwordStrength <= 1 / 4
                          ? Colors.red
                          : passwordStrength == 2 / 4
                          ? Colors.yellow
                          : passwordStrength == 3 / 4
                          ? Colors.blue
                          : Colors.green,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      passwordStrength <= 1 / 4
                          ? "Weak"
                          : passwordStrength == 2 / 4
                          ? "Fair"
                          : passwordStrength == 3 / 4
                          ? "Good"
                          : "Strong",
                      style: TextStyle(
                        color: passwordStrength <= 1 / 4
                            ? Colors.red
                            : passwordStrength == 2 / 4
                            ? Colors.yellow
                            : passwordStrength == 3 / 4
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.centerRight,
                children: [
                  MyTextField(
                    hintText: "Confirm Password",
                    obscuredText: _isConfirmObscured,
                    controller: _confirmPwController,
                    onChanged: (value) {},
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 20), // Adjust the padding here (5 pixels ~ 0.5 cm)
                    child: IconButton(
                      icon: Icon(
                        _isConfirmObscured ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmObscured = !_isConfirmObscured; // Toggle confirm password visibility
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MyButton(
                text: "Register",
                onTap: () async {
                  await register(context);
                },
              ),
              const SizedBox(height: 10),
              MyButton(
                text: "Continue with OAuth",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OAuthPage(onTap: widget.onTap)),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: const Text(
                      "Login here!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

