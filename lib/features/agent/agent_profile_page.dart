import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/agent/agent_edit_profile_page.dart';
import 'package:stayhub/features/agent/agent_settings_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:stayhub/core/image_utils.dart';
import 'package:stayhub/core/widgets/school_logo.dart';

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
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('agents').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? 'Agent';
          final email = data['email'] ?? 'No Email';
          final photoUrl = data['photoUrl'];
          final schools = List<String>.from(data['schoolsOfOperation'] ?? []);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, name, photoUrl, isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIdentitySection(context, name, email, schools, cardColor, data['partnerType'] ?? 'Agent'),
                      const SizedBox(height: 32),
                      
                      _buildSectionLabel("MANAGEMENT HUB", isDark),
                      const SizedBox(height: 16),
                      _buildActionGrid(context, cardColor, primaryColor),
                      
                      const SizedBox(height: 32),
                      _buildSectionLabel("SUPPORT & ASSISTANCE", isDark),
                      const SizedBox(height: 16),
                      _buildSupportCard(context, cardColor, primaryColor),
                      
                      const SizedBox(height: 48),
                      _buildLogoutButton(context),
                      const SizedBox(height: 60),
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

  Widget _buildSliverAppBar(BuildContext context, String name, String? photoUrl, bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        centerTitle: false,
        title: Text(
          "Business Dashboard",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        background: Container(color: isDark ? const Color(0xFF0F172A) : Colors.white),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blueAccent.withOpacity(0.1),
            backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person, size: 18, color: Colors.blueAccent) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white38 : Colors.grey[400],
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildIdentitySection(BuildContext context, String name, String email, List<String> schools, Color cardColor, String partnerType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text("VERIFIED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (partnerType == 'owner' ? Colors.purple : Colors.blueAccent).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        partnerType.toUpperCase(),
                        style: TextStyle(
                          color: partnerType == 'owner' ? Colors.purple : Colors.blueAccent, 
                          fontWeight: FontWeight.w900, 
                          fontSize: 10, 
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          Text(email, style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500)),
          
          if (schools.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSchoolsBadges(context, schools),
          ],
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, Color cardColor, Color primaryColor) {
    return Column(
      children: [
        _buildPremiumMenuTile(
          context,
          Icons.person_outline_rounded,
          "Edit Business Profile",
          "Update your bio, name and identity",
          cardColor,
          primaryColor,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentEditProfilePage()))
        ),
        const SizedBox(height: 12),
        _buildPremiumMenuTile(
          context,
          Icons.settings_suggest_outlined,
          "Professional Settings",
          "Security, privacy and app preferences",
          cardColor,
          const Color(0xFF6366F1), // Indigo
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentSettingsPage()))
        ),
      ],
    );
  }

  Widget _buildPremiumMenuTile(BuildContext context, IconData icon, String title, String subtitle, Color cardColor, Color iconColor, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context, Color cardColor, Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
            : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.headset_mic_rounded, color: Colors.blueAccent, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Support Hub", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text("Need help? Our team is available 24/7", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showSupportOptions(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("CONTACT SUPPORT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
        label: const Text("Log out Session", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 14)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSchoolsBadges(BuildContext context, List<String> schools) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('schools').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 30, child: LinearProgressIndicator());
        
        final allSchools = snapshot.data!.docs;
        
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: schools.map((schoolName) {
            final Map<String, String> fetchedLogos = {};
            for (final doc in allSchools) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString();
              final logo = (data['logo_url'] ?? data['logo'] ?? '').toString();
              if (name.isNotEmpty && logo.isNotEmpty) {
                fetchedLogos[name.toUpperCase()] = logo;
              }
            }
            
            final logoUrl = SchoolUtils.getSchoolLogo(schoolName, fetchedLogos);
            return _buildSchoolBadge(context, schoolName, logoUrl);
          }).toList(),
        );
      },
    );
  }

  Widget _buildSchoolBadge(BuildContext context, String schoolName, String? logoUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String displayName = schoolName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty) ...[
            SchoolLogo(
              logoUrl: logoUrl,
              size: 18,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 10),
          ] else ...[
            Icon(Icons.school_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
            const SizedBox(width: 8),
          ],
          Text(
            displayName.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white70 : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text("Business Support", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text("How can we assist your business today?", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 32),
              
              _buildSupportTile(context, Icons.chat_rounded, "WhatsApp Business", "Fast response for agents", Colors.green, () => _launchContact(context, 'whatsapp')),
              const SizedBox(height: 12),
              _buildSupportTile(context, Icons.phone_in_talk_rounded, "Phone Support", "Speak with our partner manager", Colors.blue, () => _launchContact(context, 'phone')),
              const SizedBox(height: 12),
              _buildSupportTile(context, Icons.mail_rounded, "Official Email", "For formal documentation", Colors.orange, () => _launchContact(context, 'email')),
              const SizedBox(height: 40),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSupportTile(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300])
          ],
        ),
      ),
    );
  }

  Future<void> _launchContact(BuildContext context, String type) async {
      try {
        final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
        final data = doc.data() ?? {};
        final studentSupport = data['student_support'] as Map<String, dynamic>?;
        final agentSupport = data['agent_support'] as Map<String, dynamic>?;
        final adminContact = data['admin_contact'] as Map<String, dynamic>?;

        String? value;
        switch(type) {
           case 'whatsapp': 
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
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact info not found.")));
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
        
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch app.")));
        }
      } catch (e) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred.")));
         }
      }
  }
}
