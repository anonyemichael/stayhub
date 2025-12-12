import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      // Force the user to select an account every time by signing out of Google first
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      // Simplified error message for the UI
      throw Exception("Google Sign-In failed. Please try again.");
    }
  }

  // ---------------------------------------------------------------------------
  // 4. SIGN OUT
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception("Error signing out");
    }
  }
  
  // ---------------------------------------------------------------------------
  // 5. PASSWORD RESET
  // ---------------------------------------------------------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // ERROR HANDLER (Makes Firebase errors readable)
  // ---------------------------------------------------------------------------
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'network-request-failed':
          return 'Please check your internet connection.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return 'An unexpected error occurred.';
  }
}