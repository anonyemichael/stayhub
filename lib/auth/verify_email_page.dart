import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/services/resend_service.dart';
import 'package:stayhub/features/agent/agent_dashboard.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _pinController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Removed EmailOTP package usage
  
  bool _isLoading = false;
  bool _canResend = false;
  String _userEmail = "";
  String _generatedOtp = "";
  
  @override
  void initState() {
    super.initState();
    _initVerification();
  }

  void _initVerification() async {
    final user = _auth.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _userEmail = user.email!;
        _isLoading = true;
      });
      // Generate OTP locally
      _generateAndSendOtp();
    }
  }

  void _generateAndSendOtp() async {
    setState(() => _isLoading = true);
    
    // Generate 6 digit random code
    var rng = Random();
    _generatedOtp = (rng.nextInt(900000) + 100000).toString();
    
    debugPrint("Generated OTP: $_generatedOtp for $_userEmail");
    
    // Send via our Secure ResendService (via Cloudflare Worker)
    bool sent = await ResendService.sendOtp(_userEmail, _generatedOtp);
    
    if (mounted) {
      if (sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent to your email.")),
        );
        setState(() => _canResend = false);
        // Cooldown for resend
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) setState(() => _canResend = true);
        });
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send code. Please try again.")),
        );
         setState(() => _canResend = true);
      }
      setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() async {
    if (_pinController.text.length != 6) return;

    setState(() => _isLoading = true);
    
    // Verify locally
    String inputOtp = _pinController.text.trim();
    bool valid = (inputOtp == _generatedOtp);
    // Backdoor for testing if email fails (optional, remove in prod)
    // if (inputOtp == "123456") valid = true; 
    
    if (valid) {
        final user = _auth.currentUser;
        if (user != null) {
          try {
            // Update in all potential collections to be safe
            final batch = FirebaseFirestore.instance.batch();
            
            batch.update(FirebaseFirestore.instance.collection('users').doc(user.uid), {'isVerified': true});
            batch.update(FirebaseFirestore.instance.collection('agents').doc(user.uid), {'isVerified': true});
            
            // Note: batch.update will fail if document doesn't exist, so we use separate try-catches or checks
            // But since we want to be fast, we'll just try updating both and ignore failures on missing docs
            try { await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isVerified': true}); } catch (_) {}
            try { await FirebaseFirestore.instance.collection('agents').doc(user.uid).update({'isVerified': true}); } catch (_) {}
            
            if (mounted) {
              // 2. Determine destination based on role
              final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(user.uid).get();
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => agentDoc.exists ? const AgentDashboard() : const MainPage()),
                );
              }
            }
         } catch (e) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
           }
         }
       }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid OTP code. Please try again.")),
        );
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
        color: Colors.black26,
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.blueAccent),
      borderRadius: BorderRadius.circular(8),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text("Verify Email"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await _auth.signOut();
              if (mounted) Navigator.pop(context); 
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white60)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              "Enter Verification Code",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              "We sent a 6-digit code to\n$_userEmail",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 40),
             Pinput(
              length: 6,
              controller: _pinController,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: (pin) => _verifyOtp(),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
               style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) 
                  : const Text("Verify & Continue"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: (_canResend && !_isLoading) ? _generateAndSendOtp : null,
              child: Text(
                _canResend ? "Resend Code" : "Resend Code (wait 30s)",
                style: TextStyle(color: _canResend ? Colors.blueAccent : Colors.white30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
