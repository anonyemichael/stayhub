import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/core/splash_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading screen while waiting for the auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // If the user is logged in, show the main page
        if (snapshot.hasData) {
          return const MainPage();
        }

        // Otherwise, show the authentication page
        return const AuthPage();
      },
    );
  }
}
