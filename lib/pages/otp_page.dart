import 'dart:async';
import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import '../services/auth/otp_service.dart';

class OTPPage extends StatefulWidget {
  final String email;
  final String username;
  final VoidCallback onOTPVerified;

  OTPPage({
    required this.email,
    required this.username,
    required this.onOTPVerified,
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
    if (await EmailOTP.verifyOTP(otp: otp)) {
      widget.onOTPVerified();
      Navigator.pop(context, otp); // Navigate back to registration page
    } else {
      // Show invalid OTP message
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
