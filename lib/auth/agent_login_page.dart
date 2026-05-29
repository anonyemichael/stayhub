import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/auth_service.dart';
import 'package:stayhub/features/agent/agent_dashboard.dart';
import 'package:stayhub/auth/agent_signup_page.dart';

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


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
        // Trigger browser to save password
        TextInput.finishAutofillContext();
        
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
        backgroundColor: isError ? Colors.red.shade900.withOpacity(0.9) : Colors.green.shade800,
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

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage("assets/logo/logo.png"),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Partner with StayHub",
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          "Access your agent dashboard",
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      body: Stack(
        children: [
          // 1. Background
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.3,
                child: Image.network(
                  "https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=2669&auto=format&fit=crop",
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
                            radius: 40,
                            backgroundColor: Colors.transparent,
                            backgroundImage: AssetImage("assets/logo/logo.png"),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
  
                      const Text(
                        "Partner Login",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Access your agent dashboard",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                      ),
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
                            child: AutofillGroup(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildGlassTextField(
                                      controller: _emailController,
                                      icon: Icons.email_outlined,
                                      hint: "Email Address",
                                      inputType: TextInputType.emailAddress,
                                      autofillHints: [AutofillHints.email],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildGlassTextField(
                                      controller: _passwordController,
                                      icon: Icons.lock_outline,
                                      hint: "Password",
                                      isPassword: true,
                                      autofillHints: [AutofillHints.password],
                                      onSubmitted: (_) => _signInAsAgent(),
                                    ),
                                    const SizedBox(height: 32),
                                    
                                    Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)], // Sophisticated Royal Blue to Deep Navy
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          )
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
                                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                            : const Text(
                                                "LOGIN TO DASHBOARD", 
                                                style: TextStyle(
                                                  color: Colors.white, 
                                                  fontWeight: FontWeight.w900, 
                                                  fontSize: 15,
                                                  letterSpacing: 1.2,
                                                )
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
  
                      const SizedBox(height: 32),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("New here?", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentSignupPage()));
                            },
                            child: const Text("Become an Agent", style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
  
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => _showCustomSnack("Contact support to reset access."),
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoIcon() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: const CircleAvatar(
        radius: 26,
        backgroundColor: Colors.transparent,
        backgroundImage: AssetImage("assets/logo/logo.png"),
      ),
    );
  }

  Widget _buildBoxedTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: inputType,
      autofillHints: autofillHints,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF2196F3),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white24,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildFormContent({bool isMobile = false}) {
    return Column(
      children: [
        // Header (Only for Tablet or Top of Form when no hero image)
        if (!isMobile && MediaQuery.of(context).size.width <= 900) ...[
          _buildHeader(),
        ] else if (!isMobile) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Agent Login",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Access your dashboard and manage listings",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
        if (!isMobile) const SizedBox(height: 40),

        // The Glass Card
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: AutofillGroup(
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
                        autofillHints: [AutofillHints.email],
                      ),
                      const SizedBox(height: 20),
                      _buildGlassTextField(
                        controller: _passwordController,
                        icon: Icons.lock_outline,
                        hint: "Password",
                        isPassword: true,
                        autofillHints: [AutofillHints.password],
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
                              color: const Color(0xFF4facfe).withOpacity(0.4),
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
        ),

        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            _showCustomSnack("Contact support to reset agent access.");
          },
          child: Text(
              "Forgot Password?",
              style: TextStyle(color: Colors.white.withOpacity(0.6))
          ),
        ),
        const SizedBox(height: 20),
        
        // --- Added Become an Agent link ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Interested in partnering?", style: TextStyle(color: Colors.white.withOpacity(0.7))),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentSignupPage()));
              },
              child: const Text("Become an Agent", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 20),
        // AGREEMENT TEXT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text.rich(
            TextSpan(
              text: "By continuing, you agree to StayHub's ",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
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
    );
  }


  Widget _buildGlassTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: inputType,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      textInputAction: onSubmitted != null ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF3B82F6),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (!isPassword && !value.contains('@')) return 'Invalid Email';
        if (isPassword && value.length < 6) return 'Too short';
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5)),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white.withOpacity(0.3),
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontWeight: FontWeight.w400),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
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

