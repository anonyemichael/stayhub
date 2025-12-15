import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/core/main_page.dart';
import 'package:stayhub/features/agent/agent_dashboard.dart';
import 'dart:async';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late Animation<double> _logoScale;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _textSlide;

  // For the background gradient animation
  late AnimationController _gradientController;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Controllers
    // Reduced duration to make it feel snappier
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    // Subtle breathing for the logo
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    // Background Gradient movement
    _gradientController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
    ]).animate(_gradientController);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight), weight: 1),
    ]).animate(_gradientController);

    // 2. Setup Tweens
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut))
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _mainController, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic))
    );

    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 1.0, curve: Curves.easeIn))
    );

    _startApp();
  }

  Future<void> _startApp() async {
    _mainController.forward();

    // PERFORMANCE OPTIMIZATION: Reduced forced delay to 500ms.
    final minDelay = Future.delayed(const Duration(milliseconds: 500));
    final navigationTask = _getDestinationScreen();

    // Use Future.wait to run parallel
    final results = await Future.wait([minDelay, navigationTask]);
    final destination = results[1] as Widget;

    if (mounted) {
      _navigate(destination);
    }
  }

  Future<Widget> _getDestinationScreen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthPage();

    try {
      // PERFORMANCE OPTIMIZATION: Sequential checks are safer but we want speed.
      // We check 'agents' first as they are likely the ones using this dashboard often? 
      // Actually, checking admins is rare. Let's keep logic but ensure it fails fast.
      
      // We use 'get(GetOptions(source: Source.serverAndCache))' by default which is good.
      
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
      if (adminDoc.exists) return const AgentDashboard(); 

      final agentDoc = await FirebaseFirestore.instance.collection('agents').doc(user.uid).get();
      if (agentDoc.exists) return const AgentDashboard();

      // Default User
      return const MainPage();
    } catch (e) {
      return const AuthPage();
    }
  }

  void _navigate(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600), // Slightly faster transition
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _topAlignmentAnimation.value,
                end: _bottomAlignmentAnimation.value,
                colors: const [
                  Color(0xFF0F2027), // Deep Dark Blue/Black
                  Color(0xFF203A43), // Dark Teal
                  Color(0xFF2C5364), // Blue Grey
                  Color(0xFF1A237E), // Deep Indigo accent
                ],
              ),
            ),
            child: Stack(
              children: [
                // 1. Background Particles (Radar)
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => CustomPaint(
                      painter: RadarPainter(_pulseController.value),
                      child: const SizedBox(width: 400, height: 400),
                    ),
                  ),
                ),

                // 2. Main Content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Stack
                      ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.05), // Subtle breathing 5%
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      blurRadius: 30,
                                      spreadRadius: -5,
                                    ),
                                  ],
                                ),
                                child: const CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: AssetImage("assets/logo/logo.png"),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Text Content
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _contentOpacity,
                          child: Column(
                            children: [
                              const Text(
                                "StayHub",
                                style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2.0,
                                    fontFamily: 'Plus Jakarta Sans' // Optional font
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Glassmorphism Tagline
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                      )
                                    ]
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.7))
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Setting up your experience...",
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.8),
                                          letterSpacing: 0.5
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Footer Copyright
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _contentOpacity,
                    child: Center(
                      child: Text(
                        "© 2025 StayHub Inc.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double animationValue;

  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      double progress = (animationValue + (i * 0.33)) % 1.0;
      double radius = progress * (size.width / 2);
      double opacity = 1.0 - progress;
      opacity = math.max(0.0, math.min(1.0, opacity));
      paint.color = Colors.white.withValues(alpha: 0.15);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
