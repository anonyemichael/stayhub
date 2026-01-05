import 'dart:ui'; // For blur effects
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter/foundation.dart'; // For kIsWeb, defaultTargetPlatform
import 'package:url_launcher/url_launcher.dart'; // For external links
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuthException
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:stayhub/services/auth_service.dart';
import 'package:stayhub/auth/signup_page.dart';
import 'package:stayhub/auth/agent_login_page.dart'; 
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/auth/forgot_password_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  bool _loading = false;
  bool _passwordVisible = false;

  // Animations
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize entrance animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutQuart));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar("Please fill in all fields", isError: true);
      return;
    }

    _setLoading(true);
    try {
      final user = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null) {
        // Just navigate home, splash screen will handle roles.
        _navigateHome();
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed. Please try again.";
      if (e.code == 'user-not-found') msg = "No account found with this email.";
      if (e.code == 'wrong-password') msg = "Invalid password. Please try again.";
      if (e.code == 'invalid-email') msg = "The email address is invalid.";
      if (e.code == 'user-disabled') msg = "This account has been disabled.";
      if (e.code == 'too-many-requests') msg = "Too many attempts. Try again later.";
      if (e.code == 'network-request-failed') msg = "No internet connection.";
      _showSnackBar(msg, isError: true);
    } catch (e) {
      _showSnackBar("An unexpected error occurred. Please try again.", isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _signInWithGoogle() async {
    _setLoading(true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _navigateHome();
      }
    } catch (e) {
      _showSnackBar("Google Sign In failed", isError: true);
    } finally {
      _setLoading(false);
    }
  }
  
  void _navigateHome() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _loading = value);
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 900) {
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
                  // Placeholder for high-quality image
                  Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage("https://images.unsplash.com/photo-1555854877-bab0e564b8d5?q=80&w=2669&auto=format&fit=crop"), // Hostel/Cozy vibe
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.5), // Overlay
                  ),
                  Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text("Find your perfect\nhome away from home.", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.1)),
                         const SizedBox(height: 20),
                         Text("Secure, verified hostels for students.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18)),
                         
                         // --- Added Download Section (Desktop) ---
                         const SizedBox(height: 40),
                         Align(
                           alignment: Alignment.centerLeft,
                           child: _buildDownloadSection(false)
                         ),
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
                      child: _buildAuthForm(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // MOBILE: CENTERED LAYOUT
    return Scaffold(
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
            top: -60,
            right: -60,
            child: _buildAmbientOrb(Colors.blue.withOpacity(0.2)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _buildAmbientOrb(Colors.purple.withOpacity(0.2)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildAuthForm(),
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

  Widget _buildAuthForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 40, spreadRadius: 2)
            ],
          ),
          child: const CircleAvatar(
            radius: 45,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage("assets/logo/logo.png"),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          "Welcome Back",
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          "Sign in to access your bookings",
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
        ),
        const SizedBox(height: 40),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _emailController,
                    hint: "Email",
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    hint: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
            },
            child: Text("Forgot Password?", style: TextStyle(color: Colors.white.withOpacity(0.8))),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _loading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade900,
              elevation: 5,
              shadowColor: Colors.blue.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text(
              "Log In",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white, size: 20),
            onPressed: _loading ? null : _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              foregroundColor: Colors.white,
            ),
            label: const Text(
              "Continue with Google",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account?", style: TextStyle(color: Colors.white.withOpacity(0.7))),
            TextButton(
              onPressed: () {
                 HapticFeedback.lightImpact(); // Attempt feedback
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage()));
              },
              child: const Text("Sign Up", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentLoginPage()));
          },
          child: Text("Login as Agent", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
        ),
        
        // --- Added Download Section (Mobile) ---
        _buildDownloadSection(true),
      ],
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
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_passwordVisible,
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
            _passwordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white54,
            size: 20,
          ),
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
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

  // --- DOWNLOAD SECTION ---

  Widget _buildDownloadSection(bool isMobileLayout) {
    if (!kIsWeb) return const SizedBox.shrink(); // Only show on Web

    final platform = defaultTargetPlatform;
    String label = "Download App";
    IconData icon = FontAwesomeIcons.download;
    VoidCallback? action;
    Color color = Colors.white;

    switch (platform) {
      case TargetPlatform.android:
        label = "Coming Soon to Play Store";
        icon = FontAwesomeIcons.googlePlay;
        color = Colors.greenAccent;
        action = () {
           _showSnackBar("Stay tuned! The Android app is launching soon.");
        };
        break;
      case TargetPlatform.iOS:
        label = "Use Web App on iOS";
        icon = FontAwesomeIcons.apple;
        // iOS users just use the browser
        break;
      case TargetPlatform.linux:
        label = "Download for Linux";
        icon = FontAwesomeIcons.linux;
        action = () => _launchURL("https://stayhubgh.com/downloads/linux"); // Placeholder
        break;
      case TargetPlatform.windows:
        label = "Download for Windows";
        icon = FontAwesomeIcons.windows;
        action = () => _launchURL("https://stayhubgh.com/downloads/windows"); // Placeholder
        break;
      default:
        // Mac or Fuchsia
        label = "Use Web App";
        break;
    }

    if (label.isEmpty) return const SizedBox.shrink();

    // Design
    return Padding(
      padding: EdgeInsets.only(top: isMobileLayout ? 30 : 0), 
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(icon, size: 16, color: color),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (action != null) ...[
                   const SizedBox(width: 8),
                   Icon(Icons.arrow_outward_rounded, size: 14, color: color.withOpacity(0.7)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar("Could not launch download link", isError: true);
    }
  }
}