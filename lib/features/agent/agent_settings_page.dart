import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/features/profile/change_password_page.dart';
import 'package:stayhub/features/profile/privacy_page.dart';
import 'package:stayhub/features/profile/terms_page.dart';
import 'package:provider/provider.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:stayhub/features/agent/agent_notification_settings_page.dart';
import 'package:stayhub/features/agent/agent_privacy_page.dart';
import 'package:stayhub/features/agent/agent_terms_page.dart';

class AgentSettingsPage extends StatelessWidget {
  const AgentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Not authenticated")));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('agents').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          bool hasCleared = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            hasCleared = data['is_test_data_cleared'] == true;
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionHeader("Security & Access", isDark),
              const SizedBox(height: 16),
              _buildSettingsTile(
                context, 
                Icons.lock_outline_rounded, 
                "Change Password", 
                "Update your security credentials", 
                cardColor, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage(collection: 'agents')))
              ),
              
              const SizedBox(height: 32),
              _buildSectionHeader("Preferences", isDark),
              const SizedBox(height: 16),
              _buildSettingsTile(
                context, 
                Icons.notifications_none_rounded, 
                "Notifications", 
                "Configure alert preferences", 
                cardColor, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentNotificationSettingsPage()))
              ),
              _buildThemeToggle(context, cardColor, isDark),
              _buildSettingsTile(
                context, 
                Icons.privacy_tip_outlined, 
                "Privacy Policy", 
                "Review data usage policies", 
                cardColor, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentPrivacyPage()))
              ),
              _buildSettingsTile(
                context, 
                Icons.description_outlined, 
                "Terms of Service", 
                "Legal agreement for partners", 
                cardColor, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgentTermsPage()))
              ),

              // ONLY SHOW IF NOT CLEARED YET
              if (!hasCleared) ...[
                const SizedBox(height: 32),
                _buildSectionHeader("Data Management (One-Time)", isDark),
                const SizedBox(height: 16),
                _buildSettingsTile(
                  context, 
                  Icons.delete_sweep_rounded, 
                  "Clear Test Earnings", 
                  "Permanently reset wallet and test history", 
                  cardColor, 
                  () => _showCleanupDialog(context, user.uid)
                ),
              ],
              
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Colors.blueAccent, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      "StayHub Business v1.0.0",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        }
      ),
    );
  }

  void _showCleanupDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Final Warning"),
        content: const Text("This will reset your wallet and delete history. Once completed, this button will disappear forever to prevent accidental use."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // 1. Reset Balance and SET FLAG
                await FirebaseFirestore.instance.collection('agents').doc(uid).update({
                  'wallet_balance': 0,
                  'walletBalance': 0,
                  'is_test_data_cleared': true // This hides the button permanently
                });

                // 2. Delete Transactions
                final txns = await FirebaseFirestore.instance.collection('agents').doc(uid).collection('transactions').get();
                final batch = FirebaseFirestore.instance.batch();
                for (var doc in txns.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Test data cleared and button removed!")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cleanup failed: $e")));
              }
            }, 
            child: const Text("CLEAR & REMOVE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, Color cardColor, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: isDark,
        onChanged: (val) => themeProvider.toggleTheme(val),
        secondary: const Icon(Icons.dark_mode_outlined, color: Colors.blueAccent, size: 24),
        title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        subtitle: const Text("Switch to a darker interface", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
        activeColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white70 : Colors.black87, letterSpacing: 0.5));
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, String subtitle, Color cardColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent, size: 24),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
