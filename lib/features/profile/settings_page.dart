import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:stayhub/features/profile/about_page.dart';
import 'package:stayhub/features/admin/admin_dashboard.dart';
import 'package:stayhub/auth/auth_page.dart'; // For redirection after delete
import 'package:stayhub/features/profile/privacy_page.dart';
import 'package:stayhub/features/profile/terms_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _appVersion = "";
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = "v${info.version}");
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("This will permanently delete your profile, bookings history, and data. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // 1. Delete Firestore Data (Check all possible collections)
        final uid = user!.uid;
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        await FirebaseFirestore.instance.collection('agents').doc(uid).delete();
        await FirebaseFirestore.instance.collection('admins').doc(uid).delete();

        // 2. Delete Auth Account
        await user!.delete();

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
               MaterialPageRoute(builder: (context) => const AuthPage()),
               (route) => false,
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login' && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Security: Please log out and log in again to delete your account.")));
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Change Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "New Password", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (passwordCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
                  return;
                }
                if (passwordCtrl.text.length < 6) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters")));
                   return;
                }

                setDialogState(() => isLoading = true);
                try {
                  await FirebaseAuth.instance.currentUser!.updatePassword(passwordCtrl.text);
                  
                  // Also update in Firestore if they are an agent and we stored it there (for legacy/admin sync)
                  final email = FirebaseAuth.instance.currentUser!.email;
                  if (email != null) {
                    await FirebaseFirestore.instance.collection('agents').doc(email).update({
                      'password': passwordCtrl.text,
                    }).catchError((_) {}); // Ignore if not an agent doc
                  }

                  if (mounted) Navigator.pop(context);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!")));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}\n(You may need to logout and login again for security)")));
                  }
                } finally {
                  if (mounted) setDialogState(() => isLoading = false);
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    
    // Modern Color Palette
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7); // iOS-like Grouped Background
    final boxColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: bgColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // 1. User Profile Header (Mini)
            if (user != null) ...[
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(user!.uid).get(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final name = data?['name'] ?? user!.displayName ?? "Student";
                  final email = data?['email'] ?? user!.email ?? "";
                  final photo = data?['photoUrl'] ?? user!.photoURL;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: photo != null ? NetworkImage(photo) : null,
                          child: photo == null ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(email, style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // 2. Appearance Section
            _buildSectionHeader("PREFERENCES", secondaryTextColor),
            Container(
              decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                   _buildSwitchTile(
                    title: "Dark Mode",
                    icon: Icons.dark_mode,
                    iconColor: Colors.indigo,
                    value: isDark,
                    boxColor: boxColor,
                    textColor: textColor,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      themeProvider.toggleTheme(val);
                    },
                  ),
                ],
              ),
            ),
            // 3. Security Section
            _buildSectionHeader("SECURITY & ACCOUNT", secondaryTextColor),
            Container(
              decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildNavTile(
                    title: "Change Password",
                    icon: Icons.lock_reset,
                    iconColor: Colors.blueAccent,
                    boxColor: boxColor,
                    textColor: textColor,
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Info & Support Section
            _buildSectionHeader("SUPPORT & ABOUT", secondaryTextColor),
            Container(
              decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildNavTile(
                    title: "Privacy Policy",
                    icon: Icons.privacy_tip,
                    iconColor: Colors.teal,
                    boxColor: boxColor,
                    textColor: textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPage()),
                    ),
                  ),
                  _buildDivider(isDark),
                  _buildNavTile(
                    title: "Terms of Service",
                    icon: Icons.description,
                    iconColor: Colors.orange,
                    boxColor: boxColor,
                    textColor: textColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsPage()),
                    ),
                  ),
                  _buildDivider(isDark),
                  _buildNavTile(
                    title: "About StayHub",
                    icon: Icons.info,
                    iconColor: Colors.blue,
                    boxColor: boxColor,
                    textColor: textColor,
                    trailing: Text(_appVersion, style: TextStyle(color: secondaryTextColor, fontSize: 14)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Danger Zone
            _buildSectionHeader("DANGER ZONE", Colors.red),
            Container(
              decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(16)),
              child: _buildNavTile(
                title: "Delete Account",
                icon: Icons.delete_forever,
                iconColor: Colors.red,
                boxColor: boxColor,
                textColor: Colors.red,
                onTap: () => _confirmDeleteAccount(context),
              ),
            ),

            // 5. DEBUG MODE: OPEN ACCESS
            if (user != null)
              Column(
                children: [
                   _buildAdminButton(context),
                   const SizedBox(height: 10),
                   const Text("DEBUG: ADMIN OPEN TO ALL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                   Text("Your email: ${user!.email}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),

             const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color? color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title, 
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title, required IconData icon, required Color iconColor,
    required bool value, required Color boxColor, required Color textColor, required ValueChanged<bool> onChanged
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor))),
          Switch.adaptive(
            value: value, 
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required String title, required IconData icon, required Color iconColor,
    required Color boxColor, required Color textColor, VoidCallback? onTap, Widget? trailing
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // More vertical padding
        child: Row(
          children: [
             Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor))),
            if (trailing != null) trailing,
            if (trailing == null) Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, thickness: 0.5, indent: 56, color: isDark ? Colors.grey[800] : Colors.grey[300]);
  }

  Widget _buildAdminButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.blue.withOpacity(0.3))
          ),
          child: const Center(
            child: Text("Access Admin Panel", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
          ),
        ),
      ),
    );
  }
}

