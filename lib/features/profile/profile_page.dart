import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- IMPORTS ---
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/profile/settings_page.dart';
import 'package:stayhub/features/profile/help_page.dart';
import 'package:stayhub/features/profile/wallet_page.dart';
import 'package:stayhub/features/profile/edit_profile_page.dart';
import 'package:stayhub/features/profile/notifications_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Use a future variable to cache the result
  late Future<DocumentSnapshot> _profileFuture;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Start fetching data immediately
    if (_uid != null) {
      _profileFuture = _fetchCorrectProfile(_uid!);
    }
  }

  // Logic: Fetch Data
  Future<DocumentSnapshot> _fetchCorrectProfile(String uid) async {
    // Attempt parallel fetching if performance is critical, but sequential is safer for "fallback" logic.
    // However, checking 'admins' first is fast if empty.
    
    // Optimistic check: Most users are regular users. Check that first? 
    // Or keep priority: Admin > Agent > User.
    
    // Let's stick to the priority but optimize if possible.
    // Actually, simple sequential check is usually fine unless latency is high.
    // To speed it up, we could trigger all 3 and see which one returns exists=true,
    // but that costs 3 reads.
    
    // For now, let's keep logic but ensure FutureBuilder doesn't rebuild constantly.
    
    var doc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    if (doc.exists) return doc;
    
    doc = await FirebaseFirestore.instance.collection('agents').doc(uid).get();
    if (doc.exists) return doc;
    
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  // Logic: Logout
  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E224F),
        title: const Text("Log Out", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to log out?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthPage()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const AuthPage();

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () {}, 
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F4397), 
              Color(0xFF382397), 
              Color(0xFF4A148C), 
            ],
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: _profileFuture, // Use cached future to prevent reload on every setState
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final email = userData['email'] ?? FirebaseAuth.instance.currentUser?.email ?? 'No Email';
            final photoUrl = userData['photoUrl'];
            final bookings = userData['bookingsCount'] ?? '0';
            final rating = userData['rating'] ?? '5.0';
            final years = userData['yearsActive'] ?? '1';

            ImageProvider<Object> profileImage;
            if (photoUrl != null && photoUrl.isNotEmpty) {
              profileImage = NetworkImage(photoUrl);
            } else {
              profileImage = const NetworkImage("https://ui-avatars.com/api/?name=Stay+Hub&background=random&size=128");
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SafeArea(
                child: Column(
                  children: [
                    // 1. PROFILE IMAGE
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: profileImage,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. EMAIL
                    Text(
                      email,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                    ),

                    const SizedBox(height: 24),

                    // 3. STATS ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(bookings.toString(), "Bookings"),
                        _buildVerticalDivider(),
                        _buildStatItem(rating.toString(), "Rating"),
                        _buildVerticalDivider(),
                        _buildStatItem(years.toString(), "Years"),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // 4. ACCOUNT SETTINGS GROUP
                    _buildSectionHeader("ACCOUNT SETTINGS"),
                    const SizedBox(height: 10),
                    Container(
                      decoration: _glassDecoration(),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            icon: Icons.person_outline,
                            text: "Edit Profile",
                            onTap: () async {
                               // Refresh profile after edit
                               await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()));
                               setState(() {
                                 _profileFuture = _fetchCorrectProfile(_uid!);
                               });
                            },
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            text: "My Wallet",
                            trailingText: "\$0.00",
                            trailingColor: Colors.greenAccent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            icon: Icons.notifications_none,
                            text: "Notifications",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsPage())),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 5. SUPPORT GROUP
                    _buildSectionHeader("SUPPORT"),
                    const SizedBox(height: 10),
                    Container(
                      decoration: _glassDecoration(),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            icon: Icons.headset_mic_outlined,
                            text: "Help & Support",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage())),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            icon: Icons.settings_outlined,
                            text: "General Settings",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 6. LOGOUT BUTTON
                    GestureDetector(
                      onTap: () => _handleLogout(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout, color: Colors.white70, size: 20),
                            const SizedBox(width: 8),
                            const Text("Log Out", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 80), 
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white.withValues(alpha: 0.2));
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    String? trailingText,
    Color? trailingColor
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              if (trailingText != null) ...[
                Text(trailingText, style: TextStyle(color: trailingColor ?? Colors.white, fontSize: 14)),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.05), indent: 64, endIndent: 16);
  }
}
