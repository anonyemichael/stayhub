import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCreateAgentPage extends StatefulWidget {
  const AdminCreateAgentPage({super.key});

  @override
  State<AdminCreateAgentPage> createState() => _AdminCreateAgentPageState();
}

class _AdminCreateAgentPageState extends State<AdminCreateAgentPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _hostelCtrl = TextEditingController();
  bool _isLoading = false;

  // A unique name for the temporary Firebase app instance to avoid conflicts.
  static const _tempAppName = 'TemporaryAgentCreator';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _hostelCtrl.dispose();
    super.dispose();
  }

  Future<void> _spawnAgent() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: _tempAppName,
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final newAgentUid = userCredential.user?.uid;
      if (newAgentUid == null) {
        throw Exception("Failed to get new agent UID.");
      }

      await FirebaseFirestore.instance.collection('agents').doc(newAgentUid).set({
        'uid': newAgentUid,
        'email': _emailCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'hostelName': _hostelCtrl.text.trim().isEmpty ? 'Not Assigned' : _hostelCtrl.text.trim(),
        'role': 'agent',
        'isVerified': true, 
        'balance': 0.0,
        'hostels': [],
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 5.0,
        'password': _passCtrl.text.trim(), // Storing for admin reference
      });
      
      if (mounted) {
        _showSuccess();
        _clearForm();
      }

    } on FirebaseAuthException catch (e) {
      _showError(_getFriendlyAuthError(e.code));
    } catch (e) {
      _showError("An unexpected error occurred: $e");
    } finally {
      if (tempApp != null) {
        await tempApp.delete();
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _emailCtrl.clear();
    _passCtrl.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _hostelCtrl.clear();
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text("Agent Created", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "The agent account is active. They can now log into their portal immediately.",
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text("Awesome", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            ),
          )
        ],
      ),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error), 
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getFriendlyAuthError(String code) {
    switch (code) {
      case 'weak-password': return 'Password is too weak.';
      case 'email-already-in-use': return 'Email already registered.';
      case 'invalid-email': return 'Email is invalid.';
      default: return 'Auth Error: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Agent Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [Theme.of(context).scaffoldBackgroundColor, const Color(0xFF121212)]
              : [Colors.white, const Color(0xFFF5F5F5)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blueAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "This will create a new login account. The agent will be verified automatically.",
                          style: TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                _buildInputField(_nameCtrl, "Agent Full Name", Icons.person_outline),
                const SizedBox(height: 20),
                _buildInputField(_emailCtrl, "Email Address", Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 20),
                _buildInputField(_passCtrl, "Initial Password", Icons.lock_outline, isPassword: true),
                const SizedBox(height: 20),
                _buildInputField(_phoneCtrl, "Phone Number", Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 20),
                _buildInputField(_hostelCtrl, "Assigned Hostel (Optional)", Icons.domain_outlined),
                
                const SizedBox(height: 40),

                // Premium Button
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)]),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6)
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _spawnAgent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text(
                          "CREATE AGENT ACCOUNT", 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)
                        ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, bool isPassword = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          obscureText: isPassword,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 22),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), 
              borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
          validator: (v) {
             if (ctrl != _hostelCtrl && (v == null || v.trim().isEmpty)) return "Required";
             return null;
          },
        ),
      ],
    );
  }
}
