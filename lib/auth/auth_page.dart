import 'dart:ui'; // For blur effects
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter/foundation.dart'; // For kIsWeb, defaultTargetPlatform
import 'package:url_launcher/url_launcher.dart'; // For external links
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuthException
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final _formKey = GlobalKey<FormState>();

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
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      _setLoading(false);
    }
  }
  
  void _navigateHome() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    
    // Tell the OS password manager that login succeeded so it can prompt to save the credentials
    TextInput.finishAutofillContext();
    
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
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027), // Midnight Slate
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: isDesktop ? 0.3 : 0.15,
                child: Image.network(
                  "https://images.weserv.nl/?url=images.pexels.com/photos/1454806/pexels-photo-1454806.jpeg&w=1600&fit=cover",
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Brand Logo
                      Hero(
                        tag: 'logo',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.transparent,
                            backgroundImage: AssetImage("assets/logo/logo.png"),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildHeader(),
                      const SizedBox(height: 40),
  
                      // Form Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                )
                              ],
                            ),
                            child: _buildAuthForm(),
                          ),
                        ),
                      ),
  
                      const SizedBox(height: 32),
                      _buildOrDivider(),
                      const SizedBox(height: 32),
  
                      // Google Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _signInWithGoogle,
                          icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                          label: const Text("Continue with Google", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.15)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
  
                      const SizedBox(height: 40),
                      
                      // High Visibility Sign Up Link
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text("New here? ", style: TextStyle(color: Colors.white60)),
                              Text("Create Student Account", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentLoginPage())),
                        child: const Text("Partner Login (Agents/Owners)", style: TextStyle(color: Colors.white38, fontSize: 13)),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Student Login",
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          "Welcome back to StayHub",
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _emailController,
              hint: "Email Address",
              icon: Icons.email_rounded,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              hint: "Password",
              icon: Icons.lock_rounded,
              isPassword: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
              child: const Text("Forgot Password?", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("LOG IN", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("OR", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Iterable<String>? autofillHints,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_passwordVisible,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction ?? (onSubmitted != null ? TextInputAction.done : TextInputAction.next),
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
        break;
      case TargetPlatform.linux:
        label = "Download for Linux";
        icon = FontAwesomeIcons.linux;
        action = () => _launchURL("https://stayhubgh.com/downloads/linux");
        break;
      case TargetPlatform.windows:
        label = "Download for Windows";
        icon = FontAwesomeIcons.windows;
        action = () => _launchURL("https://stayhubgh.com/downloads/windows");
        break;
      default:
        label = "Use Web App";
        break;
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
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
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar("Could not launch download link", isError: true);
    }
  }
}