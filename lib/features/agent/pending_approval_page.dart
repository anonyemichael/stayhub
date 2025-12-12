import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/auth/auth_page.dart';

class PendingApprovalPage extends StatefulWidget {
  const PendingApprovalPage({super.key});

  @override
  State<PendingApprovalPage> createState() => _PendingApprovalPageState();
}

class _PendingApprovalPageState extends State<PendingApprovalPage> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Setup Pulse Animation (Heartbeat effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
            (route) => false,
      );
    }
  }

  void _contactSupport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Support email copied: support@stayhub.com")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // 2. Animated Status Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withOpacity(0.1), // Soft Warning Color
                  ),
                  child: Center(
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent,
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]
                      ),
                      child: const Icon(Icons.hourglass_top_rounded, size: 40, color: Colors.white),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 3. Main Text
              const Text(
                "Under Review",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Plus Jakarta Sans', // If you have it, else default
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Thanks for joining StayHub! We are currently verifying your agent credentials.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 50),

              // 4. Progress Stepper (The "Timeline")
              _buildProgressStep(
                title: "Registration",
                subtitle: "Account created successfully",
                isActive: true,
                isCompleted: true,
                isLast: false,
              ),
              _buildProgressStep(
                title: "Verification",
                subtitle: "Admin reviewing details (24-48hrs)",
                isActive: true,
                isCompleted: false,
                isLast: false,
              ),
              _buildProgressStep(
                title: "Approval",
                subtitle: "Access to Agent Dashboard",
                isActive: false,
                isCompleted: false,
                isLast: true,
              ),

              const Spacer(flex: 3),

              // 5. Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text("Log Out"),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _contactSupport,
                    icon: const Icon(Icons.help_outline, size: 20),
                    label: const Text("Contact Help"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSABLE TIMELINE WIDGET ---
  Widget _buildProgressStep({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            // The Dot
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? Colors.green : (isActive ? Colors.amber : Colors.grey[200]),
                border: Border.all(
                  color: isCompleted ? Colors.green : (isActive ? Colors.amber : Colors.grey[300]!),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : (isActive ? const Center(child: SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))) : null),
            ),
            // The Line
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? Colors.green.withOpacity(0.5) : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 16),
        // The Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive || isCompleted ? Colors.black87 : Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20), // Spacing for next item
            ],
          ),
        )
      ],
    );
  }
}