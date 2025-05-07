import 'package:SafeChat/services/auth/auth_service.dart';
import 'package:SafeChat/services/auth/login_or_register.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../pages/home_page.dart';

class AuthGate extends StatelessWidget {
   AuthGate({super.key});

  final AuthService _authService = AuthService();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context,snapshot){
          //user is logged in

          if(snapshot.hasData){
            return HomePage(isLoggedIn: _authService.isLoggedIn);

          }
          //user is logged out
          else{
            return const LoginOrRegister();
          }

        },
      ),
    );
  }
}
