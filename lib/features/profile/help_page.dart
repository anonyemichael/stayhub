import 'dart:ui'; // For ImageFilter
import 'dart:math'; // For background animations
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  // WhatsApp Configuration
  final String _whatsappNumber = "233509483401";

  // Animations
  late AnimationController _bgController;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    // 1. Background Breathing Animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // 2. Staggered Entrance Animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _launchWhatsApp() async {
    HapticFeedback.heavyImpact(); // Strong feedback for main action
    final Uri url = Uri.parse("https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent('Hello StayHub, I need help with...')}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack("Could not launch WhatsApp", isError: true);
      }
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    }
  }

  Future<void> _launchEmail() async {
    HapticFeedback.lightImpact();
    final Uri url = Uri(scheme: 'mailto', path: 'support@stayhub.app');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.black,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    // We force a dark/rich theme for this specific page to make it look premium
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. ANIMATED BACKGROUND (The "Breathing" Effect)
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                children: [
                  // Deep Base
                  Container(color: const Color(0xFF0F172A)),

                  // Moving Blob 1 (Purple)
                  Positioned(
                    top: -100 + (_bgController.value * 50),
                    left: -50,
                    child: _buildBlurCircle(300, Colors.purpleAccent.withOpacity(0.3)),
                  ),

                  // Moving Blob 2 (Blue)
                  Positioned(
                    bottom: -50 - (_bgController.value * 50),
                    right: -50,
                    child: _buildBlurCircle(350, Colors.blueAccent.withOpacity(0.2)),
                  ),

                  // Moving Blob 3 (Cyan/Green for Ghana vibe)
                  Positioned(
                    top: 200,
                    right: -100 + (_bgController.value * 30),
                    child: _buildBlurCircle(200, Colors.tealAccent.withOpacity(0.15)),
                  ),
                ],
              );
            },
          ),

          // 2. GLASS CONTENT
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildGlassButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                      const Text(
                        "CONCIERGE",
                        style: TextStyle(color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      _buildGlassButton(Icons.more_horiz, () {}),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),

                        // Hero Text
                        _buildAnimatedItem(0, const Text(
                          "We are here\nto help.",
                          style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, height: 1.1),
                        )),

                        const SizedBox(height: 30),

                        // Search Field (Floating)
                        _buildAnimatedItem(1, ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                hintText: "Search knowledge base...",
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(20),
                              ),
                            ),
                          ),
                        )),

                        const SizedBox(height: 40),

                        // --- THE MAIN ACTIONS ---

                        // 1. WHATSAPP (Hero Button)
                        _buildAnimatedItem(2, GestureDetector(
                          onTap: _launchWhatsApp,
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF25D366), Color(0xFF128C7E)], // Official WhatsApp Colors
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF25D366).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.message_rounded, color: Colors.white, size: 36),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Chat on WhatsApp", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text("Instant reply • Online", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        )),

                        const SizedBox(height: 16),

                        // 2. Secondary Actions Row
                        _buildAnimatedItem(3, Row(
                          children: [
                            Expanded(child: _buildSecondaryAction("Email Support", Icons.mail_outline, Colors.purpleAccent, _launchEmail)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSecondaryAction("Live Agent", Icons.headset_mic_outlined, Colors.blueAccent, () => _showSnack("Connecting..."))),
                          ],
                        )),

                        const SizedBox(height: 40),

                        // FAQ Section
                        _buildAnimatedItem(4, Row(
                          children: [
                            Text("Quick Answers", style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold)),
                            const Spacer(),
                            const Icon(Icons.arrow_downward, color: Colors.white30, size: 16),
                          ],
                        )),
                        const SizedBox(height: 16),

                        _buildAnimatedItem(5, _buildGlassFAQList()),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 60, spreadRadius: 20)],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildSecondaryAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassFAQList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getFaqs(),
      builder: (context, snapshot) {
        // Mock Data if empty
        var docs = snapshot.data?.docs ?? [];
        final mockData = [
          {'q': "How do I make payment?", 'a': "We accept MTN Mobile Money and Vodafone Cash directly in the app."},
          {'q': "Is my booking secure?", 'a': "Yes, all bookings are verified by the university housing committee."},
        ];

        final count = docs.isEmpty ? mockData.length : docs.length;

        return Column(
          children: List.generate(count, (index) {
            final q = docs.isEmpty ? mockData[index]['q'] : (docs[index].data() as Map)['question'];
            final a = docs.isEmpty ? mockData[index]['a'] : (docs[index].data() as Map)['answer'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: Colors.white70,
                  collapsedIconColor: Colors.white30,
                  title: Text(q, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(a, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                    )
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Animation Helper
  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceController, curve: Interval(index * 0.15, 1.0, curve: Curves.easeOut)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _entranceController, curve: Interval(index * 0.15, 1.0, curve: Curves.easeOut)),
        ),
        child: child,
      ),
    );
  }
}