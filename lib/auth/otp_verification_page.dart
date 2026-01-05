import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:stayhub/auth/new_password_page.dart';
import 'package:stayhub/services/resend_service.dart';

class OtpVerificationPage extends StatefulWidget {
  final String targetOtp;
  final String email;

  const OtpVerificationPage({
    super.key,
    required this.targetOtp,
    required this.email,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _canResend = false;
  late String _currentOtp;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.targetOtp;
    // Enable resend after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) setState(() => _canResend = true);
    });
  }

  void _verifyOtp() async {
    final otp = _pinController.text;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the full 6-digit code")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    // Check local verification first
    bool valid = otp == _currentOtp;
    
    if (valid) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NewPasswordPage(email: widget.email)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid OTP, please try again.")),
        );
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _resendOtp() async {
    setState(() => _isLoading = true);
    
    // Generate new OTP
    final newOtp = (100000 + Random().nextInt(900000)).toString();
    
    bool sent = await ResendService.sendOtp(widget.email, newOtp);
    setState(() => _isLoading = false);
    
    if (sent) {
      setState(() => _currentOtp = newOtp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP has been resent to your email.")),
      );
      setState(() => _canResend = false);
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) setState(() => _canResend = true);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to resend OTP. Try again later.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Theme Config
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFF4FACFE), width: 1.5),
      color: Colors.white.withValues(alpha: 0.15),
      boxShadow: [
        BoxShadow(color: const Color(0xFF4FACFE).withValues(alpha: 0.3), blurRadius: 12),
      ]
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight, 
            colors: [
              Color(0xFF141E30),
              Color(0xFF243B55),
            ]
          )
        ),
        child: Center(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Icon Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
                    ]
                  ),
                  child: const Icon(Icons.shield_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 30),

                // 2. Glass Card
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))]
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Verification",
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Enter the 6-digit code sent to\n${widget.email}",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 30),

                      // PIN Input
                      Pinput(
                        length: 6,
                        controller: _pinController,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                        showCursor: true,
                        cursor: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(width: 2, height: 20, color: const Color(0xFF4FACFE)),
                          ],
                        ),
                        onCompleted: (pin) => _verifyOtp(),
                      ),
                      const SizedBox(height: 40),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)]),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Verify Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Resend Link
                      GestureDetector(
                        onTap: (_canResend && !_isLoading) ? _resendOtp : null,
                        child: Text(
                          _canResend ? "Resend Code" : "Resend Code in 30s",
                          style: TextStyle(
                            color: _canResend ? const Color(0xFF4FACFE) : Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ),
      ),
    ); 
  }
}
