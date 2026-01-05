import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/auth/auth_page.dart';

class NewPasswordPage extends StatefulWidget {
  final String? code;
  final String? email; // Optional, just for display/verification if needed

  const NewPasswordPage({super.key, this.code, this.email});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  void _resetPassword() async {
    final password = _passwordController.text;
    if (password != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters")));
      return;
    }

    if (widget.code == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid reset code. Please request a new link.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.confirmPasswordReset(code: widget.code!, newPassword: password);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Your password has been reset successfully. You can now login with your new password."),
            actions: [
              TextButton(
                onPressed: () {
                   Navigator.pop(context); // Close dialog
                   // Navigate to Login Page
                   Navigator.of(context).pushAndRemoveUntil(
                     MaterialPageRoute(builder: (_) => const AuthPage()),
                     (route) => false,
                   );
                },
                child: const Text("Go to Login"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is FirebaseAuthException) {
          msg = e.message ?? "An error occurred";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $msg")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF141E30), // Deep rich blue/black
              Color(0xFF243B55), // Lighter metallic blue
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Icon / Logo Area
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_reset_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 30),

                // 2. Glassmorphic Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                         color: Colors.black.withOpacity(0.1),
                         blurRadius: 30,
                         offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Reset Password",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter your new secure password below.",
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                      ),
                      if (widget.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.email!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 30),

                      // New Password Field
                      _buildPremiumTextField(
                        label: "New Password",
                        controller: _passwordController,
                        visible: _isPasswordVisible,
                        toggle: (v) => setState(() => _isPasswordVisible = v),
                      ),
                      const SizedBox(height: 20),

                      // Confirm Password Field
                      _buildPremiumTextField(
                        label: "Confirm Password",
                        controller: _confirmController,
                        visible: _isConfirmVisible,
                        toggle: (v) => setState(() => _isConfirmVisible = v),
                      ),
                      const SizedBox(height: 30),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      "Update Password",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required Function(bool) toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: !visible,
            style: const TextStyle(color: Colors.white),
            cursorColor: const Color(0xFF4FACFE),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: IconButton(
                icon: Icon(
                  visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                onPressed: () => toggle(!visible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
