import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stayhub/services/auth_service.dart';
import 'package:stayhub/features/agent/agent_dashboard.dart';

class AgentLoginPage extends StatefulWidget {
  // Removed 'const' to avoid potential instantiation issues in parent widgets
  const AgentLoginPage({super.key});

  @override
  State<AgentLoginPage> createState() => _AgentLoginPageState();
}

class _AgentLoginPageState extends State<AgentLoginPage> with TickerProviderStateMixin {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  // Animations
  late AnimationController _backgroundController;
  late Animation<Offset> _orb1Animation;
  late Animation<Offset> _orb2Animation;

  @override
  void initState() {
    super.initState();
    // Setup floating background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _orb1Animation = Tween<Offset>(
      begin: const Offset(-0.2, -0.2),
      end: const Offset(0.2, 0.2),
    ).animate(CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut));

    _orb2Animation = Tween<Offset>(
      begin: const Offset(0.2, 0.2),
      end: const Offset(-0.2, -0.2),
    ).animate(CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _signInAsAgent() async {
    // Dismiss Keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate(); // Error haptic
      return;
    }

    setState(() => _loading = true);

    try {
      final user = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user == null) throw FirebaseAuthException(code: 'unknown', message: 'Login failed.');

      // Check Firestore Role
      final doc = await FirebaseFirestore.instance.collection('agents').doc(user.uid).get();

      if (!mounted) return;

      if (doc.exists) {
        HapticFeedback.heavyImpact(); // Success haptic
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AgentDashboard()),
        );
      } else {
        await _authService.signOut();
        _showCustomSnack("Access Denied: Not an Agent account.", isError: true);
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Authentication failed";
      if (e.code == 'user-not-found') msg = "No agent found with this email.";
      if (e.code == 'wrong-password') msg = "Invalid password. Please try again.";
      if (e.code == 'invalid-email') msg = "The email address is invalid.";
      if (e.code == 'network-request-failed') msg = "No internet connection.";
      if (e.code == 'too-many-requests') msg = "Too many attempts. Try again later.";
      _showCustomSnack(msg, isError: true);
    } catch (e) {
      _showCustomSnack("An unexpected error occurred. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCustomSnack(String message, {bool isError = false}) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade900.withValues(alpha: 0.9) : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    // 1. Full Screen Layout
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Tap anywhere to dismiss keyboard
      child: Scaffold(
        backgroundColor: Colors.black, // Fallback color
        body: Stack(
          children: [
            // 2. Animated Background
            _buildAnimatedBackground(),

            // 3. Frosted Glass Content
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      children: [
                    // Dynamic Greeting
                    Text(
                      _timeGreeting(),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w300
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Agent Portal",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0
                      ),
                    ),
                    const SizedBox(height: 40),

                    // The Glass Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildGlassTextField(
                                  controller: _emailController,
                                  icon: Icons.email_outlined,
                                  hint: "Email Address",
                                  inputType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 20),
                                _buildGlassTextField(
                                  controller: _passwordController,
                                  icon: Icons.lock_outline,
                                  hint: "Password",
                                  isPassword: true,
                                ),
                                const SizedBox(height: 30),

                                // Modern Gradient Button
                                Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4facfe).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _signInAsAgent,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: _loading
                                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                        : const Text("LOGIN TO DASHBOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password logic
                        _showCustomSnack("Contact support to reset agent access.");
                      },
                      child: Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6))
                      ),
                    ),
                    const SizedBox(height: 20),
                    // AGREEMENT TEXT
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text.rich(
                        TextSpan(
                          text: "By continuing, you agree to StayHub's ",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          children: [
                            TextSpan(
                              text: "Terms",
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()..onTap = () => launchUrl(
                                Uri.parse('https://stayhubgh.com/terms.html'),
                                mode: LaunchMode.inAppWebView,
                              ),
                            ),
                            const TextSpan(text: " and "),
                            TextSpan(
                              text: "Privacy Policy",
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()..onTap = () => launchUrl(
                                Uri.parse('https://stayhubgh.com/privacy.html'),
                                mode: LaunchMode.inAppWebView,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F2027), // Deep Blue/Black
                Color(0xFF203A43), // Tealish
                Color(0xFF2C5364), // Lighter Blue
              ],
            ),
          ),
        ),
        // Moving Orb 1
        SlideTransition(
          position: _orb1Animation,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withValues(alpha: 0.3),
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withValues(alpha: 0.3), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
        ),
        // Moving Orb 2
        SlideTransition(
          position: _orb2Animation,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withValues(alpha: 0.2),
                boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.cyanAccent,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (!isPassword && !value.contains('@')) return 'Invalid Email';
        if (isPassword && value.length < 6) return 'Too short';
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white60,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
      ),
    );
  }
}
