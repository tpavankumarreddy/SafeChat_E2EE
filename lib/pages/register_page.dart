import 'package:emailchat/services/auth/auth_service.dart';
import 'package:emailchat/components/my_button.dart';
import 'package:emailchat/components/my_textfield.dart';
import 'package:flutter/material.dart';
import 'package:email_otp/email_otp.dart';
import '../services/auth/otp_service.dart';

class RegisterPage extends StatelessWidget{

  EmailOTP myAuth = EmailOTP();

  final TextEditingController _nameController=TextEditingController();
  final TextEditingController _emailController=TextEditingController();
  final TextEditingController _pwController=TextEditingController();
  final TextEditingController _confirmPwController=TextEditingController();
  final TextEditingController _otpController=TextEditingController();

  final void Function()? onTap;



  RegisterPage({super.key,required this.onTap});

  //register method

  Future<void> register(BuildContext context) async {
    // get authservice
    final auth=AuthService();
    final otpService = OTPService(); // Instantiate OTPService
    final emailotp = EmailOTP();

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


    //passwordds match means create user
    if (_pwController.text==_confirmPwController.text&&  _pwController.text.length>=6) {
      try{
        //String otp = OTPService.generateOTP();
        await otpService.sendOTP(myAuth,_emailController.text,_nameController.text);
        //emailotp.sendOTP();
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
                  onPressed: ()  async {
                    final value = _otpController.text;
                    if (EmailOTP.verifyOTP(otp: value)) {
                    print("OTP is verified");
                    auth.signUpWithEmailPassword(_emailController.text, _pwController.text, value);
                    Navigator.pop(context);
                    } else{
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Invalid OTP.", style: TextStyle(fontSize: 18)),
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
                    Future.delayed(const Duration(seconds: 1), () {
                      Navigator.pop(context);
                    });
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      } catch(e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(e.toString()),
          ),
        );
      }

    }
    else if(_pwController.text!=_confirmPwController.text) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Passwords don't match", style: TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: ()  {
                Navigator.pop(context);
              },
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    }
    //passwords not match means show error
    else{
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Password length should be at least 6.", style: TextStyle(fontSize: 18)),
            actions: [
              TextButton(
                onPressed: ()  {
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
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //logo
            Icon(Icons.message,
              size : 60,
              color: Theme.of(context).colorScheme.primary,
            ),

            const SizedBox(height: 50),
            //welcome back
            Text("Hello, let's get you registered.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize:18,
              ),
            ),

            const SizedBox(height: 50),

            MyTextField(
              hintText: "Name",
              obscuredText: false,
              controller: _nameController,
            ),

            const SizedBox(height: 10),

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

            const SizedBox(height: 10),

            MyTextField(
              hintText: "Confirm Password",
              obscuredText: true,
              controller: _confirmPwController,
            ),

            const SizedBox(height: 25),

            //login

            MyButton(
              text: "Register",
              onTap: () => register(context),
            ),

            const SizedBox(height: 20),
            //register
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