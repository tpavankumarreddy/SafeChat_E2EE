import 'dart:async';
import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/otp_service.dart';
import 'login_page.dart';

class OTPPage extends StatefulWidget {
  final String email;
  final String username;
  final String password;

  OTPPage({
    required this.email,
    required this.username,
    required this.password,
  });

  @override
  _OTPPageState createState() => _OTPPageState();
}

class _OTPPageState extends State<OTPPage> {
  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _focusNodes;
  bool _showResendButton = false;
  int _remainingTime = 60;
  Timer? _timer;

  EmailOTP myAuth = EmailOTP();
  final otpService = OTPService();

  @override
  void initState() {
    super.initState();
    _otpControllers = List.generate(6, (index) => TextEditingController());
    _focusNodes = List.generate(6, (index) => FocusNode());
    _sendOTP();
    _startTimer();
  }

  Future<void> _sendOTP() async {
    await OTPService().sendOTP(myAuth, widget.email, widget.username);
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((controller) => controller.text).join();

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
                Text('Please wait, your keys generating...'),
              ],
            ),
          ),
        );
      },
    );

    if (await EmailOTP.verifyOTP(otp: otp)) {
      final auth = AuthService();
      try {
        await auth.signUpWithEmailPassword(widget.email, widget.password,otp);

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Registration Successful! 🥳 Your account has been created."),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);

      } on Exception catch (e) {
        if (e.toString().contains('email-already-in-use')) {
          showDialog(
            context: context,
            builder: (context) =>
                AlertDialog(
                  title: const Text("Email already in use"),
                  content: const Text(
                      "This email is already registered. Please login instead."),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                LoginPage(onTap: () {},),
                          ),
                        );
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
            builder: (context) =>
                AlertDialog(
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
    } else {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Invalid OTP."),
        ),
      );
    }
  }


  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        setState(() {
          _showResendButton = true;
        });
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onOtpFieldChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OTP Verification')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: 40,
                  margin: EdgeInsets.symmetric(horizontal: 5),
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _focusNodes[index],
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (value) => _onOtpFieldChanged(value, index),
                    decoration: InputDecoration(
                      counterText: '',
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 20),
            Text('Resend OTP in $_remainingTime seconds'),
            SizedBox(height: 20),
            if (_showResendButton)
              TextButton(
                onPressed: () {
                  _sendOTP();
                  _startTimer();
                  setState(() {
                    _showResendButton = false;
                    _remainingTime = 60;
                  });
                },
                child: Text('Resend OTP'),
              ),
            ElevatedButton(
              onPressed: _verifyOTP,
              child: Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
