import 'package:flutter/material.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/auth/agent_login_page.dart';
import 'package:stayhub/auth/signup_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F2027) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(context, isDark),
            _buildFeatureSection(context, isDark),
            _buildCTASection(context),
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isDark) {
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.75,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage("https://images.unsplash.com/photo-1555854811-8af2277f2421?q=80&w=1600&auto=format&fit=crop"),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F2027).withOpacity(0.2),
                const Color(0xFF0F2027),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "EST. 2024",
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Booking\nMade Brilliant.",
                style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.5),
              ),
              const SizedBox(height: 16),
              Text(
                "Find verified hostels, book with ease, and live comfortably. The standard in student housing.",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryButton(
                      context, 
                      "FIND A HOSTEL", 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthPage()))
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      context, 
                      "FOR AGENTS", 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentLoginPage()))
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureSection(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Why StayHub?",
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.w900, 
              color: isDark ? Colors.white : const Color(0xFF0F172A)
            ),
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.verified_user_rounded, 
            "100% Verified Properties", 
            "We physically inspect every hostel to ensure what you see is what you get.",
            isDark
          ),
          _buildFeatureItem(
            Icons.videocam_rounded, 
            "Clips & Virtual Tours", 
            "Watch short video tours of rooms before you ever set foot on the property.",
            isDark
          ),
          _buildFeatureItem(
            Icons.security_rounded, 
            "Secure Digital Payments", 
            "Your money is safe with us. We handle payments securely via major local gateways.",
            isDark
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(32),
        image: const DecorationImage(
          image: NetworkImage("https://www.transparenttextures.com/patterns/cubes.png"),
          opacity: 0.05,
        ),
      ),
      child: Column(
        children: [
          const Text(
            "Ready to move in?",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            "Join 5,000+ students finding their safe space.",
            style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("CREATE FREE ACCOUNT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apartment_rounded, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "STAYHUB", 
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 2, 
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                )
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "The #1 Student Accommodation Partner in Ghana.",
            style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
             "© 2026 StayHub. All rights reserved.",
             style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, String label, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildSecondaryButton(BuildContext context, String label, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
      ),
    );
  }
}
