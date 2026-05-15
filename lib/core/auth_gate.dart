import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/auth/verify_email_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/auth/landing_page.dart';
import 'package:stayhub/features/agent/agent_dashboard.dart';
import 'package:stayhub/features/admin/admin_dashboard.dart';
import 'package:stayhub/core/splash_screen.dart';
import 'package:stayhub/features/agent/pending_approval_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String> _getAndCacheUserRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;

      // 1. Check Admin
      const superAdmins = ['anonyemichael6@gmail.com', 'admin@stayhub.com'];
      if (email != null && superAdmins.contains(email)) return 'admin';

      if (email != null) {
        final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(email).get();
        if (adminDoc.exists) return 'admin';
      }

      // 2. Check Agent
      final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(uid).get();
      if (agentDoc.exists) {
        final data = agentDoc.data() as Map<String, dynamic>;
        if (data['isBlocked'] == true) return 'blocked';
        if (data['isVerified'] != true) return 'agent_pending'; // Must be verified
        
        await prefs.setString('user_role', 'agent');
        return 'agent';
      }

      // 3. Check Student (Users)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          if (userData['isBlocked'] == true) return 'blocked';
          
          // Force verification if not Google user and not verified in Firestore
          final isGoogleUser = FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
          if (!isGoogleUser && userData['isVerified'] == false) return 'unverified';
        }
      }

      await prefs.setString('user_role', 'student');
      return 'student'; // Default
    } catch (e) {
      debugPrint("Error fetching role: $e");
      return 'student'; // Fail safe
    }
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
              
              switch (role) {
                case 'admin':
                  return const AdminDashboard();
                case 'agent':
                  return const AgentDashboard();
                case 'agent_pending':
                  return const PendingApprovalPage();
                case 'unverified':
                  return const VerifyEmailPage();
                case 'blocked':
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                            "Account Suspended",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text("Please contact support for assistance."),
                        ],
                      ),
                    ),
                  );
                default:
                  return const MainPage();
              }
            },
          );
        }

        return const LandingPage();
      },
    );
  }
}
