import 'dart:ui'; // Crucial for ImageFilter
import 'dart:math'; // For the background blob movement
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/services/firestore_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  // --- ANIMATION CONTROLLERS ---
  late AnimationController _bgController;
  late AnimationController _entranceController;
  
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final _currencyFormat = NumberFormat.currency(locale: 'en_GH', symbol: '₵');

  @override
  void initState() {
    super.initState();
    // 1. The "Breathing" Background Animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // 2. Staggered Entrance for elements
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // The "StayHub Premium" Dark Blue
      body: Stack(
        children: [
          // --- LAYER 1: ANIMATED AMBIENT BACKGROUND ---
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(color: const Color(0xFF0F172A)),
                  // Blob 1: Purple (Top Left)
                  Positioned(
                    top: -100 + (_bgController.value * 30),
                    left: -50,
                    child: _buildBlurCircle(300, Colors.purpleAccent.withValues(alpha: 0.2)),
                  ),
                  // Blob 2: Cyan (Bottom Right)
                  Positioned(
                    bottom: -50 - (_bgController.value * 50),
                    right: -100,
                    child: _buildBlurCircle(350, Colors.cyanAccent.withValues(alpha: 0.15)),
                  ),
                  // Blob 3: Blue (Center moving)
                  Positioned(
                    top: 300,
                    left: -50 + (_bgController.value * 60),
                    child: _buildBlurCircle(250, Colors.blueAccent.withValues(alpha: 0.1)),
                  ),
                ],
              );
            },
          ),

          // --- LAYER 2: GLASS CONTENT ---
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildGlassIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                      const Text(
                        "MY WALLET",
                        style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 3,
                            fontWeight: FontWeight.bold,
                            fontSize: 14
                        ),
                      ),
                      _buildGlassIconButton(Icons.qr_code_scanner, () {}),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. The Credit Card (Real Data)
                        StreamBuilder<DocumentSnapshot>(
                          stream: _firestoreService.getWalletBalance(user.uid),
                          builder: (context, snapshot) {
                            double balance = 0.0;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
                            }
                            return _buildAnimatedItem(0, _buildCreditCard(balance));
                          },
                        ),

                        const SizedBox(height: 30),

                        // 2. Action Buttons
                        _buildAnimatedItem(1, Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActionButton(Icons.add, "Top Up", Colors.greenAccent),
                            _buildActionButton(Icons.arrow_outward, "Send", Colors.orangeAccent),
                            _buildActionButton(Icons.receipt_long, "Bills", Colors.blueAccent),
                            _buildActionButton(Icons.more_horiz, "More", Colors.purpleAccent),
                          ],
                        )),

                        const SizedBox(height: 40),

                        // 3. Transactions Header
                        _buildAnimatedItem(2, Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Recent Activity", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("See All", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                          ],
                        )),

                        const SizedBox(height: 15),

                        // 4. Transaction List (Real Data)
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestoreService.getUserTransactions(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final docs = snapshot.data?.docs ?? [];
                            
                            if (docs.isEmpty) {
                              return _buildAnimatedItem(3, 
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(child: Text("No transactions yet", style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))),
                                )
                              );
                            }

                            return _buildAnimatedItem(3, Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                                final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                                final isExpense = data['type'] == 'expense';
                                
                                return _buildTransactionTile(
                                  data['title'] ?? 'Transaction',
                                  "${isExpense ? '-' : '+'} ${_currencyFormat.format(amount)}",
                                  DateFormat('MMM d').format(date),
                                  isExpense
                                );
                              }).toList(),
                            ));
                          },
                        ),
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

  // --- WIDGET BUILDERS (MATCHING YOUR STYLE) ---

  // The "Breathing" Blobs
  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 10)],
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  // Glass Header Buttons
  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // The "Hero" Credit Card
  Widget _buildCreditCard(double balance) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Current Balance", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Icon(Icons.wifi, color: Colors.white.withValues(alpha: 0.6)),
                ],
              ),
              Text(
                _currencyFormat.format(balance), 
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("**** **** **** 4209", style: TextStyle(color: Colors.white70, letterSpacing: 2)),
                  Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Circular Action Buttons
  Widget _buildActionButton(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => HapticFeedback.mediumImpact(),
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Glass Transaction List Tile
  Widget _buildTransactionTile(String title, String amount, String date, bool isNegative) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNegative ? Colors.redAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isNegative ? Icons.arrow_outward : Icons.arrow_downward,
              color: isNegative ? Colors.redAccent : Colors.greenAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(date, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: isNegative ? Colors.white : Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Staggered Entry Animation
  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceController, curve: Interval(index * 0.2, 1.0, curve: Curves.easeOut)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _entranceController, curve: Interval(index * 0.2, 1.0, curve: Curves.easeOut)),
        ),
        child: child,
      ),
    );
  }
}
