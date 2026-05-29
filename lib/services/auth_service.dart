import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
// For debugPrint
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:stayhub/core/api_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '33041190550-pa4rcbsoac2b4irda7g0lonl5rpnpuef.apps.googleusercontent.com' : null,
    serverClientId: kIsWeb ? null : '33041190550-pa4rcbsoac2b4irda7g0lonl5rpnpuef.apps.googleusercontent.com',
  );

  // Get current user (useful for checking if logged in)
  User? get currentUser => _auth.currentUser;

  // Stream to listen to auth changes (Log in / Log out updates)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // 1. SIGN UP (Email & Password)
  // ---------------------------------------------------------------------------
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 2. SIGN IN (Email & Password)
  // ---------------------------------------------------------------------------
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // 3. GOOGLE SIGN IN
  // ---------------------------------------------------------------------------
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        // WEB: Use Firebase Auth's built-in Popup (More reliable for Web)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // MOBILE (Android/iOS): Use GoogleSignIn Plugin
        await _googleSignIn.signOut(); // Force account selection
        
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // Cancelled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }
      
      final user = userCredential.user;
      if (user != null) {
        // Automatically sync Google Profile (including photoUrl) to Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': user.displayName ?? "Student",
            'email': user.email ?? "",
            'photoUrl': user.photoURL ?? "",
            'role': 'student',
            'createdAt': FieldValue.serverTimestamp(),
            'isVerified': true,
          });
        } else {
          // If the document exists but is missing the photoUrl, update it.
          final data = userDoc.data() as Map<String, dynamic>;
          if ((data['photoUrl'] == null || data['photoUrl'].toString().isEmpty) && user.photoURL != null) {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'photoUrl': user.photoURL,
              if (data['name'] == null) 'name': user.displayName,
            });
          }
        }
      }
      return user;
    } catch (e) {
      debugPrint("Error during Google Sign-In: $e");
      if (e is FirebaseAuthException) {
        throw Exception(_handleAuthError(e));
      }
      throw Exception("Google Sign-In failed: ${e.toString()}");
    }
  }

  // ---------------------------------------------------------------------------
  // 4. SIGN OUT
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    try {
      // Clear FCM Token from Database before signing out of Auth
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        }).catchError((e) => debugPrint("Error clearing token: $e"));
        
        // Also clear from agents collection if they are an agent
        await FirebaseFirestore.instance.collection('agents').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        }).catchError((e) => null); // Ignore error if not an agent
      }

      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("SignOut Error: $e");
      throw Exception("Error signing out");
    }
  }
  
  // ---------------------------------------------------------------------------
  // 5. PASSWORD RESET (Via Node.js Backend on Render)
  // ---------------------------------------------------------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Use Central API Config
      const String backendUrl = ApiConfig.sendPasswordReset;

      debugPrint("Sending reset request to: $backendUrl");

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode == 200) {
        debugPrint("Reset email sent via Backend.");
        return; // Success
      } else {
        debugPrint("Backend Error: ${response.body}");
        try {
           final body = jsonDecode(response.body);
           if (body['message'] != null) {
              throw Exception(body['message']);
           }
        } catch (_) {}
        
        // If the server is down or returns error, fallback to Firebase default?
        // Risky if the goal is strictly to avoid spam, but better than nothing for UX.
        // Actually, if backend fails, likely due to config, let's throw to warn dev.
        throw Exception("Failed to send reset email via custom server. Check server logs.");
      }
    } catch (e) {
       debugPrint("Custom Reset Error: $e");
       // Fallback to Firebase Default (with spam warning in UI)
       // Uncomment below line if you want fallback enabled:
       // await _auth.sendPasswordResetEmail(email: email);
       rethrow; // Rethrow to show error in UI
    }
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLER (Makes Firebase errors readable)
  // ---------------------------------------------------------------------------
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already in use. Please try logging in.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Your password is too weak. Please use a stronger password.';
        case 'user-not-found':
          return 'No account found with this email. Please sign up.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'unauthorized-domain':
          return 'Domain not authorized. Please add it in Firebase Console.';
        case 'popup-closed-by-user':
          return 'Sign in cancelled.';
        default:
          return 'Authentication failed. Please try again (${e.code}).';
      }
    }
    return e.toString();
  }
}