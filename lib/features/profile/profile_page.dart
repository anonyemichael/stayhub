import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter
import 'package:stayhub/features/profile/help_page.dart'; // Support Page


import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/profile/edit_profile_page.dart';
import 'package:stayhub/features/profile/notifications_settings_page.dart';
import 'package:stayhub/features/profile/settings_page.dart';
import 'package:stayhub/features/profile/wallet_page.dart';
import 'package:stayhub/features/chat/student_inbox_page.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Simplified to only fetch the current user's data from the appropriate collection.
  Stream<DocumentSnapshot> _userStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    // This assumes the AuthGate has already routed the user to the correct dashboard.
    // We can simplify this further by passing the user role, but this is a good first step.
    return FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
  }


  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role'); // Clear the cached role
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildSkeletonLoader();
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(context, data),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _controller,
                        child: _buildStatsRow(data),
                      ),
                      const SizedBox(height: 30),
                      _buildAnimatedMenuSection(
                        title: "ACCOUNT",
                        delay: 200,
                        items: [
                          _buildMenuItem(Icons.person, "Edit Profile", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()))),
                          _buildMenuItem(Icons.wallet, "Wallet", trailing: "GHS ${data['walletBalance'] ?? '0.00'}", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()))),
                          _buildMenuItem(Icons.message_outlined, "Messages", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentInboxPage()))),
                          _buildMenuItem(Icons.notifications, "Notifications", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsPage()))),
                          _buildMenuItem(Icons.headset_mic_outlined, "Help & Support", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage()))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildAnimatedMenuSection(
                        title: "PREFERENCES",
                        delay: 400,
                        items: [
                          _buildMenuItem(Icons.dark_mode, "Theme", onTap: () {
                             final themeProvider = context.read<ThemeProvider>();
                             themeProvider.toggleTheme(!themeProvider.isDarkMode);
                          }),
                        ],
                      ),
                      const SizedBox(height: 40),
                      _buildLogoutButton(context),
                      const SizedBox(height: 120), // Increased padding
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, Map<String, dynamic> data) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0F172A),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF0F172A)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Hero(
                tag: 'profile_pic',
                child: Container(
                  margin: const EdgeInsets.only(top: 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(data['photoUrl'] ?? "https://ui-avatars.com/api/?name=${data['name'] ?? 'S'}&background=random&size=128"),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    data['name'] ?? "Welcome Back",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data['email'] ?? "user@stayhub.com",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat(data['bookingsCount']?.toString() ?? "0", "Bookings"),
          Container(height: 30, width: 1, color: Colors.white24),
          _buildStat(data['rating']?.toString() ?? "0.0", "Rating"),
          Container(height: 30, width: 1, color: Colors.white24),
          _buildStat(data['yearsActive']?.toString() ?? "1", "Years"),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildAnimatedMenuSection({required String title, required int delay, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(title, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [for (int i = 0; i < items.length; i++) ...[items[i], if (i != items.length - 1) Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 56)]],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {String? trailing, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))),
              if (trailing != null) Padding(padding: const EdgeInsets.only(right: 8), child: Text(trailing, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14))),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleLogout(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.redAccent.withOpacity(0.2), Colors.redAccent.withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child: const Center(child: Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return const Center(
        child: CircularProgressIndicator(color: Colors.white)
    );
  }
}
