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
  bool _isLoading = false;

  // A unique name for the temporary Firebase app instance to avoid conflicts.
  static const _tempAppName = 'TemporaryAgentCreator';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _spawnAgent() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    FirebaseApp? tempApp;
    try {
      // THE MAGIC TRICK: Initialize a secondary Firebase App instance.
      // This allows us to use a separate authentication client to create a new user
      // without logging the current admin user out.
      tempApp = await Firebase.initializeApp(
        name: _tempAppName,
        options: Firebase.app().options,
      );

      // 1. Create the new agent user in Firebase Authentication via the temporary app.
      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final newAgentUid = userCredential.user?.uid;
      if (newAgentUid == null) {
        throw Exception("Failed to get new agent UID.");
      }

      // 2. Save the agent's profile to the 'agents' collection in your main Firestore database.
      await FirebaseFirestore.instance.collection('agents').doc(newAgentUid).set({
        'uid': newAgentUid,
        'email': _emailCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': 'agent',
        'status': 'active', // Agents are active immediately since an admin is creating them.
        'createdAt': FieldValue.serverTimestamp(),
        'hostelName': 'Not Assigned',
        'rating': 5.0,
      });
      
      if (mounted) {
        _showSuccess();
        _clearForm();
      }

    } on FirebaseAuthException catch (e) {
      _showError(_getFriendlyAuthError(e.code));
    } catch (e) {
      _showError("An unexpected error occurred. Please try again.");
    } finally {
      // 3. IMPORTANT: Always delete the temporary app instance to free up resources.
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
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.greenAccent), 
          SizedBox(width: 10), 
          Text("Agent Spawned", style: TextStyle(color: Colors.white))
        ]),
        content: const Text(
          "This agent can now log in immediately using the Agent Portal.",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Done", style: TextStyle(color: Colors.blueAccent))
          )
        ],
      ),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: Colors.red.shade700),
    );
  }

  String _getFriendlyAuthError(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak (must be at least 6 characters).';
      case 'email-already-in-use':
        return 'An account already exists for that email address.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'An unknown authentication error occurred. Code: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    // A custom theme is used to give this admin page a unique "hacker mode" look and feel.
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101010),
        primaryColor: Colors.greenAccent,
        inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIconColor: Colors.greenAccent
        )
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("GOD MODE: Create Agent"),
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "NEW OPERATIVE",
                  style: TextStyle(color: Colors.greenAccent, letterSpacing: 2, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildField(_nameCtrl, "Full Name", Icons.person_outline),
                const SizedBox(height: 15),
                _buildField(_phoneCtrl, "Phone Number", Icons.phone, type: TextInputType.phone),
                const SizedBox(height: 15),
                _buildField(_emailCtrl, "Email Address", Icons.alternate_email, type: TextInputType.emailAddress),
                const SizedBox(height: 15),
                _buildField(_passCtrl, "Initial Password", Icons.lock_outline, isPassword: true),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _spawnAgent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.2),
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.greenAccent) 
                      : const Text("SPAWN AGENT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build a consistently styled text field for this form.
  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text, bool isPassword = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return "This field is required";
        }
        if (isPassword && v.length < 6) {
          return "Password must be at least 6 characters";
        }
        if (type == TextInputType.emailAddress && !v.contains('@')) {
          return "Please enter a valid email";
        }
        return null;
      },
    );
  }
}