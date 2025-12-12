import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:stayhub/features/profile/privacy_page.dart';
import 'package:stayhub/features/profile/terms_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/features/admin/admin_create_agent.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  String _appVersion = "Loading...";
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = "v${info.version} (build ${info.buildNumber})");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Settings", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAppearanceSection(isDark, theme, themeProvider, textColor),
          const SizedBox(height: 30),
          _buildInfoSection(isDark, theme, textColor),
          const SizedBox(height: 50),
          Center(
            child: Text(_appVersion, style: TextStyle(color: textColor.withValues(alpha: 0.3), fontWeight: FontWeight.bold)),
          ),
          // --- GOD MODE CHECK ---
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              // THE SECRET CHECK - UPDATED WITH YOUR EMAIL
              if (user != null && user.email == "anonyemichael6@gmail.com") {
                return Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 20),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        // Open the Secret Page
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCreateAgentPage()));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security, color: Colors.redAccent, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "ADMIN PORTAL", 
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink(); // Hide for everyone else
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(bool isDark, ThemeData theme, ThemeProvider themeProvider, Color textColor) {
    return _buildAnimatedSection(
      index: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("VISUALS", isDark),
          const SizedBox(height: 10),
          _buildAppearanceCard(theme.cardColor, isDark, textColor, themeProvider),
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isDark, ThemeData theme, Color textColor) {
    return _buildAnimatedSection(
      index: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("INFO", isDark),
          const SizedBox(height: 10),
          _buildInfoCard(theme.cardColor, isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(Color cardColor, bool isDark, Color textColor, ThemeProvider themeProvider) {
    return Container(
      decoration: _cardDecoration(cardColor, isDark),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Appearance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const SizedBox(height: 4),
                Text(isDark ? "Dark Mode Active" : "Light Mode Active", style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              themeProvider.toggleTheme(!isDark);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 55, height: 30, padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: isDark ? Colors.blueAccent : Colors.grey[300]),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                  child: Icon(isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 16, color: isDark ? Colors.blueAccent : Colors.orange),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(Color cardColor, bool isDark, Color textColor) {
    return Container(
      decoration: _cardDecoration(cardColor, isDark),
      child: Column(
        children: [
           _buildTile(icon: Icons.shield_moon_rounded, color: Colors.teal, title: "Privacy & Security", textColor: textColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPage()))),
           _buildDivider(isDark),
          _buildTile(icon: Icons.info_outline, color: Colors.orangeAccent, title: "About StayHub", textColor: textColor, onTap: _showAboutDialog),
          _buildDivider(isDark),
          _buildTile(icon: Icons.description_outlined, color: Colors.indigoAccent, title: "Terms of Service", textColor: textColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage()))),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection({required int index, required Widget child}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Interval(index * 0.2, 1.0, curve: Curves.easeOut))),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Interval(index * 0.2, 1.0, curve: Curves.easeOut))),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white38 : Colors.grey.shade500, letterSpacing: 1.5)),
    );
  }

  BoxDecoration _cardDecoration(Color color, bool isDark) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
    );
  }

  Widget _buildTile({required IconData icon, required Color color, required String title, String? subtitle, required Color textColor, Widget? trailingWidget, required VoidCallback onTap}) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)))],
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
            if (trailingWidget == null) Icon(Icons.chevron_right_rounded, color: textColor.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, thickness: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey.shade100);
  }

  void _showAboutDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [Icon(Icons.hub, color: Colors.blueAccent), SizedBox(width: 10), Text("StayHub")]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const Text("The easiest way for students to find accommodation."), const SizedBox(height: 10), Text("Version: $_appVersion", style: const TextStyle(color: Colors.grey, fontSize: 12))],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Awesome"))],
        )
    );
  }
}
