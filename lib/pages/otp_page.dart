import 'package:flutter/material.dart';
import 'package:emailchat/services/auth/auth_service.dart';
import 'package:email_otp/email_otp.dart';
import '../services/auth/otp_service.dart';

class otpPage extends StatelessWidget {
  final TextEditingController _controller1 = TextEditingController();
  final TextEditingController _controller2 = TextEditingController();
  final TextEditingController _controller3 = TextEditingController();
  final TextEditingController _controller4 = TextEditingController();
  final TextEditingController _controller5 = TextEditingController();
  final TextEditingController _controller6 = TextEditingController();


  otpPage({Key? key}) : super(key: key);

  EmailOTP myAuth = EmailOTP();
  final _auth = AuthService();
  final otpService = OTPService(); // Instantiate OTPService
  final emailotp = EmailOTP();

  void verifyOTP(BuildContext context) async {
    String otp = _controller1.text +
        _controller2.text +
        _controller3.text +
        _controller4.text;
    print('Entered OTP: $otp');

    // You can use the entered OTP to verify it or perform any other action
    try {
      if (await myAuth.verifyOTP(otp: otp)) {
        // OTP verification successful, proceed with your logic
        print('OTP is verified');
      } else {
        // OTP verification failed, show an error message
        print('Invalid OTP');
      }
    } catch (e) {
      print('Error occurred while verifying OTP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.domain_verification,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 50),
            Text(
              "OTP Verification",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 22,
              ),
            ),
            SizedBox(height: 20),
            Text(
              "OTP has been successfully sent to your email address.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 50),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildTextField(_controller1),
                buildTextField(_controller2),
                buildTextField(_controller3),
                buildTextField(_controller4),
                buildTextField(_controller5),
                buildTextField(_controller6),

              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    // Implement resend OTP functionality
                  },
                  child: Text('Resend OTP'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => verifyOTP(context),
              child: Text('Verify OTP'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(TextEditingController controller) {
    return SizedBox(
      width: 50.0,
      height: 60.0,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.grey,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.blue,
            ),
          ),
        ),
        maxLength: 1,
      ),
    );
  }
}
