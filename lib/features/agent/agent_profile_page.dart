import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/profile/edit_profile_page.dart';
import 'package:stayhub/features/agent/agent_hostels_page.dart';
import 'package:stayhub/features/agent/agent_wallet_page.dart';
// import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart'; // Unused -> REMOVED
import 'package:url_launcher/url_launcher.dart';

class AgentProfilePage extends StatelessWidget {
  const AgentProfilePage({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await FirebaseAuth.instance.signOut();
    if (Navigator.of(context).mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthPage();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      color: bgColor,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('agents').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? 'Agent';
          final email = data['email'] ?? 'No Email';
          final photoUrl = data['photoUrl'];

          return ListView(
            padding: const EdgeInsets.all(20.0),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildProfileHeader(context, name, email, photoUrl, containerColor, textColor),
              const SizedBox(height: 32),
              
              Text("Account Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              
              _buildMenuItem(context, Icons.edit_outlined, "Edit Profile", containerColor, textColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()))),
              _buildMenuItem(context, Icons.business_center_outlined, "Hostel Management", containerColor, textColor, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                  appBar: AppBar(title: Text("Manage Hostels", style: TextStyle(color: textColor))),
                  body: const AgentHostelsPage(), 
                )));
              }),
              _buildMenuItem(context, Icons.history, "Payout History", containerColor, textColor, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                   appBar: AppBar(title: Text("Wallet & Payouts", style: TextStyle(color: textColor))),
                   body: const AgentWalletPage(),
                 )));
              }),
              
              const SizedBox(height: 32),
              Text("Support", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 16),
              
              _buildMenuItem(context, Icons.support_agent, "Contact Support", containerColor, textColor, () => _showSupportOptions(context)),
              
              const SizedBox(height: 32),
              
              // Logout Button
              GestureDetector(
                onTap: () => _handleLogout(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );

        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String email, String? photoUrl, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2), width: 3),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              backgroundColor: Colors.grey[200],
              child: photoUrl == null ? Icon(Icons.person, size: 40, color: Colors.grey[400]) : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: const Text("Verified Agent", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, Color bgColor, Color textColor, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: divIcon(context, icon),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
  
  Widget divIcon(BuildContext context, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Theme.of(context).primaryColor),
    );
  }

  void _showSupportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const Text("How can we help?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Select a channel to contact our dedicated agent support team.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                _buildSupportTile(context, Icons.chat, "WhatsApp Support", "Fastest Response", Colors.green, () => _launchContact(context, 'whatsapp')),
                const SizedBox(height: 16),
                _buildSupportTile(context, Icons.call, "Call Hotline", "Speak to a Human", Colors.blue, () => _launchContact(context, 'phone')),
                const SizedBox(height: 16),
                _buildSupportTile(context, Icons.email_outlined, "Email Support", "For Documentation", Colors.orange, () => _launchContact(context, 'email')),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSupportTile(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                  Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color)
          ],
        ),
      ),
    );
  }

  Future<void> _launchContact(BuildContext context, String type) async {
      try {
        final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
        final data = doc.data() ?? {};
        
        // Extract nested maps
        final studentSupport = data['student_support'] as Map<String, dynamic>?;
        final agentSupport = data['agent_support'] as Map<String, dynamic>?;
        final adminContact = data['admin_contact'] as Map<String, dynamic>?;

        String? value;
        switch(type) {
           case 'whatsapp': 
             // Try student whatsapp, then admin phone
             value = studentSupport?['whatsapp'] ?? adminContact?['phone']; 
             break;
           case 'phone': 
             value = adminContact?['phone'] ?? studentSupport?['whatsapp']; 
             break;
           case 'email': 
             value = agentSupport?['email'] ?? adminContact?['email']; 
             break;
        }
        
        if (value == null || value.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact info not found. Please ask Admin to set it.")));
           return;
        }
        
        Uri uri;
        if (type == 'whatsapp') {
           String num = value.replaceAll(RegExp(r'\D'), ''); 
           uri = Uri.parse("https://wa.me/$num"); 
        } else if (type == 'phone') {
           uri = Uri.parse("tel:$value");
        } else {
           uri = Uri.parse("mailto:$value");
        }
        
        debugPrint("Launching $type: $uri");
        
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            // Fallback for some devices
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch app.")));
        }
      } catch (e) {
         debugPrint("Error: $e");
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred.")));
      }
  }
}

