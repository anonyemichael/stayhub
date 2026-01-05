import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:stayhub/services/auth_service.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/auth/verify_email_page.dart';
import 'package:stayhub/features/profile/privacy_page.dart';
import 'package:stayhub/features/profile/terms_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _acceptedTerms = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty) {
      _showSnack("Please enter your full name.");
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnack("Passwords do not match.");
      return;
    }
    if (!_acceptedTerms) {
      _showSnack("You must agree to the Terms & Privacy Policy.");
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Create Firestore Profile
        await _firestoreService.updateUserProfile(user.uid, {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': 'student',
          'createdAt': DateTime.now(),
          'isVerified': false,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            // Navigate to Verification Page
            MaterialPageRoute(builder: (_) => const VerifyEmailPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Signup failed. Please try again.";
      if (e.code == 'email-already-in-use') msg = "This email is already registered. Please Log In.";
      if (e.code == 'weak-password') msg = "Password is too weak. Try a stronger one.";
      if (e.code == 'invalid-email') msg = "The email address is invalid.";
      if (e.code == 'network-request-failed') msg = "No internet connection.";
      _showSnack(msg);
    } catch (e) {
      _showSnack("An unexpected error occurred. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
      }
    } catch (e) {
      _showSnack("Google Sign In failed. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 900) {
      // DESKTOP: SPLIT LAYOUT
      return Scaffold(
        backgroundColor: const Color(0xFF0F2027),
        body: Row(
          children: [
            // Left Panel: Brand / Image
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        // Vibrant community/student group photo
                        image: NetworkImage("https://images.unsplash.com/photo-1511632765486-a01980e01a18?q=80&w=2670&auto=format&fit=crop"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2), // Lighter at top to show image
                          Colors.black.withValues(alpha: 0.8), // Darker at bottom for text
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text("Join the community.", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.1)),
                         const SizedBox(height: 20),
                         Text("Connect with thousands of students finding their perfect stay.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            // Right Panel: Form
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF0F2027),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        children: [
                          // Custom Header for Desktop Form
                          const Align(alignment: Alignment.centerLeft, child: Text("Create Account", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
                          const SizedBox(height: 10),
                          const Align(alignment: Alignment.centerLeft, child: Text("Start your journey with StayHub", style: TextStyle(fontSize: 16, color: Colors.white70))),
                          const SizedBox(height: 40),
                          _buildFormContent(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // MOBILE: EXISTING LAYOUT
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -100, left: -50,
            child: _buildAmbientOrb(Colors.blueAccent.withOpacity(0.3)),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: _buildAmbientOrb(Colors.purpleAccent.withOpacity(0.2)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                           _buildHeader(),
                           const SizedBox(height: 40),
                           _buildFormContent(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      children: [
          _buildSignupForm(),
          const SizedBox(height: 30),
          _buildSignupButton(),
          const SizedBox(height: 24),
          _buildOrDivider(),
          const SizedBox(height: 24),
          _buildGoogleButton(),
          const SizedBox(height: 30),
          _buildLoginLink(),
          const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 40, spreadRadius: 5)
            ],
          ),
          child: const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage("assets/logo/logo.png"),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          "Join StayHub",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Create an account to start your journey",
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _buildTextField(controller: _nameController, hint: "Full Name", icon: Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(controller: _emailController, hint: "Email Address", icon: Icons.email_outlined),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                hint: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isVisible: _passwordVisible,
                onVisibilityToggle: () => setState(() => _passwordVisible = !_passwordVisible),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                hint: "Confirm Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isVisible: _confirmPasswordVisible,
                onVisibilityToggle: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),
              const SizedBox(height: 20),
              _buildTermsCheckbox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _acceptedTerms = !_acceptedTerms);
      },
      child: Row(
        children: [
          SizedBox(
            height: 24, width: 24,
            child: Checkbox(
              value: _acceptedTerms,
              activeColor: Colors.blueAccent,
              side: const BorderSide(color: Colors.white54, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => setState(() => _acceptedTerms = v!),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: "I agree to the ",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                children: [
                  TextSpan(
                    text: "Terms of Service",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TermsPage()),
                        );
                      },
                  ),
                  const TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacyPage()),
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _loading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("Or continue with", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _signInWithGoogle,
        icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
        label: const Text("Google", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: RichText(
        text: TextSpan(
          text: "Already have an account? ",
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
          children: const [
            TextSpan(
              text: "Log In",
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientOrb(Color color) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 100)],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.blueAccent,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white54,
            size: 20,
          ),
          onPressed: onVisibilityToggle,
        )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
      ),
    );
  }
}
