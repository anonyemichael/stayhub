import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:stayhub/services/auth_service.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/agent/pending_approval_page.dart';
import 'package:stayhub/features/profile/privacy_page.dart';
import 'package:stayhub/features/profile/terms_page.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:stayhub/core/image_utils.dart';
import 'package:stayhub/core/widgets/school_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AgentSignupPage extends StatefulWidget {
  const AgentSignupPage({super.key});

  @override
  State<AgentSignupPage> createState() => _AgentSignupPageState();
}

class _AgentSignupPageState extends State<AgentSignupPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<String> _selectedSchools = [];
  
  String _partnerType = 'agent'; // 'agent' or 'owner'
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
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolsController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _phoneController.text.isEmpty ||
        _selectedSchools.isEmpty) {
      _showSnack("Please fill in all details.");
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
        // Trigger browser to save password
        TextInput.finishAutofillContext();

        // Create Agent Profile in Firestore
        await _firestoreService.updateUserProfile(user.uid, {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'agent', 
          'partnerType': _partnerType, 
          'schoolsOfOperation': _selectedSchools,
          'status': 'pending', 
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
          'profileComplete': false, // To prompt for bank details later
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PendingApprovalPage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Signup failed. Please try again.";
      if (e.code == 'email-already-in-use') msg = "This email is already registered.";
      if (e.code == 'weak-password') msg = "Password is too weak.";
      _showSnack(msg);
    } catch (e) {
      _showSnack("An unexpected error occurred. Please try again.");
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
                  "https://images.unsplash.com/photo-1560518883-ce09059eeffa?q=80&w=2673&auto=format&fit=crop",
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
                        "Agent Registration",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Partner with the #1 student platform",
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Partner Role", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    _buildRoleSelector(),
                                    const SizedBox(height: 24),
                                    
                                    _buildGlassTextField(
                                      controller: _nameController,
                                      icon: Icons.business_rounded,
                                      hint: "Business / Full Name",
                                      autofillHints: [AutofillHints.name],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlassTextField(
                                      controller: _emailController,
                                      icon: Icons.email_rounded,
                                      hint: "Work Email Address",
                                      inputType: TextInputType.emailAddress,
                                      autofillHints: [AutofillHints.email],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlassTextField(
                                      controller: _phoneController,
                                      icon: Icons.phone_rounded,
                                      hint: "Phone Number",
                                      inputType: TextInputType.phone,
                                      autofillHints: [AutofillHints.telephoneNumber],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    const Text("Schools of Operation", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    _buildSchoolChips(),
                                    
                                    const SizedBox(height: 24),
                                    _buildGlassTextField(
                                      controller: _passwordController,
                                      icon: Icons.lock_outline,
                                      hint: "Password",
                                      isPassword: true,
                                      isVisible: _passwordVisible,
                                      onVisibilityToggle: () => setState(() => _passwordVisible = !_passwordVisible),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlassTextField(
                                      controller: _confirmPasswordController,
                                      icon: Icons.lock_outline,
                                      hint: "Confirm Password",
                                      isPassword: true,
                                      isVisible: _confirmPasswordVisible,
                                      onVisibilityToggle: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                                      onSubmitted: (_) => _signUp(),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildTermsCheckbox(),
                                    const SizedBox(height: 32),
                                    
                                    Container(
                                      width: double.infinity,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
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
                                        onPressed: _loading ? null : _signUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: _loading
                                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                            : const Text("CREATE ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2)),
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
                          Text("Already a partner?", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Log In", style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w900)),
                          ),
                        ],
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

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildRoleTab("agent", "Agent")),
          Expanded(child: _buildRoleTab("owner", "Owner")),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String type, String label) {
    bool isSelected = _partnerType == type;
    return GestureDetector(
      onTap: () => setState(() => _partnerType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolChips() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("No schools available", style: TextStyle(color: Colors.white30, fontSize: 12));
        
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: docs.map((doc) {
            final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';
            final isSelected = _selectedSchools.contains(name);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) _selectedSchools.remove(name);
                  else _selectedSchools.add(name);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  name,
                  style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
      child: Row(
        children: [
          SizedBox(
            height: 24, width: 24,
            child: Checkbox(
              value: _acceptedTerms,
              activeColor: const Color(0xFF3B82F6),
              side: const BorderSide(color: Colors.white24, width: 2),
              onChanged: (v) => setState(() => _acceptedTerms = v!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: "I agree to the ",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                children: [
                  TextSpan(
                    text: "Terms",
                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage())),
                  ),
                  const TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage())),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    TextInputType inputType = TextInputType.text,
    Iterable<String>? autofillHints,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      keyboardType: inputType,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction ?? (onSubmitted != null ? TextInputAction.done : TextInputAction.next),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF3B82F6),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white.withOpacity(0.3), size: 20),
                onPressed: onVisibilityToggle,
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
      ),
    );
  }
}
