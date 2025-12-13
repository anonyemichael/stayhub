import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/agent/agent_dashboard.dart';
import 'package:stayhub/core/splash_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String> _getAndCacheUserRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    String role = 'student'; // Default role

    try {
      if ((await FirebaseFirestore.instance.collection('admins').doc(uid).get()).exists) {
        role = 'admin';
      } else if ((await FirebaseFirestore.instance.collection('agents').doc(uid).get()).exists) {
        role = 'agent';
      }
      await prefs.setString('user_role', role); // Cache the role
    } catch (e) {
      debugPrint("Error fetching/caching role: $e");
    }
    return role;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (authSnapshot.hasData) {
          return FutureBuilder<String>(
            future: _getAndCacheUserRole(authSnapshot.data!.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              final role = roleSnapshot.data;
              if (role == 'admin' || role == 'agent') {
                return const AgentDashboard();
              } else {
                return const MainPage();
              }
            },
          );
        }

        return const AuthPage();
      },
    );
  }
}
