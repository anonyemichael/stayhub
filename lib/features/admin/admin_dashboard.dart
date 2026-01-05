import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:stayhub/features/admin/views/admin_stats_view.dart';
import 'package:stayhub/features/admin/views/admin_users_view.dart';
import 'package:stayhub/features/admin/views/admin_earnings_view.dart';
import 'package:stayhub/features/admin/views/admin_hostels_view.dart';
import 'package:stayhub/features/admin/views/admin_config_view.dart';
import 'package:stayhub/features/admin/views/admin_bookings_view.dart';
// Reusing Settings for now

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/features/admin/views/admin_manage_admins_view.dart';
import 'package:stayhub/features/agent/agent_clips_page.dart'; // Added for Content Moderation

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String? _adminRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRole();
  }

  Future<void> _fetchRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final email = user.email?.trim().toLowerCase();
      // 1. HARDCODED SUPER ADMINS (GOD MODE)
      const superAdmins = ['anonyemichael6@gmail.com', 'admin@stayhub.com'];
      
      if (email != null && superAdmins.contains(email)) {
         debugPrint("GOD MODE ACTIVE: $email");
         if (mounted) setState(() => _adminRole = 'super_admin');
         if (mounted) setState(() => _isLoading = false);
         return;
      }

      // 2. FIRESTORE ROLE CHECK
      try {
        final doc = await FirebaseFirestore.instance.collection('admins').doc(user.email).get();
        if (doc.exists) {
           if (mounted) setState(() => _adminRole = doc.data()?['role']);
        } else {
           // Fallback for debug: If not in DB but accessed panel, make them Content Admin
           if (mounted) setState(() => _adminRole = 'content_admin'); 
        }
      } catch (e) {
        debugPrint("Error fetching role: $e");
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isSuper = _adminRole == 'super_admin';
    
    // 1. Define Main Views
    final List<Widget> pages = [
       // Tab 0: Overview (Stats for everyone, gated inside)
       AdminStatsView(isSuper: isSuper), 
       
       // Tab 1: Bookings
       const AdminBookingsView(),
       
       // Tab 2: Hostels
       AdminHostelsView(isSuper: isSuper),
       
       // Tab 3: Menu (The rest)
       _AdminMenuPage(isSuper: isSuper, role: _adminRole),
    ];

    // 2. Define Bottom Tabs
    final List<GButton> tabs = [
       GButton(icon: LineIcons.pieChart, text: _selectedIndex == 0 ? 'Home' : '', iconColor: Colors.blue),
       GButton(icon: LineIcons.book, text: _selectedIndex == 1 ? 'Bookings' : '', iconColor: Colors.purple),
       GButton(icon: LineIcons.building, text: _selectedIndex == 2 ? 'Hostels' : '', iconColor: Colors.orange),
       GButton(icon: LineIcons.bars, text: _selectedIndex == 3 ? 'Menu' : '', iconColor: Colors.pink),
    ];

    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.05))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12), // Cleaner spacing
          child: GNav(
            rippleColor: Colors.grey[200]!,
            hoverColor: Colors.grey[100]!,
            gap: 6, // Slightly reduced gap
            activeColor: Colors.white,
            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // Reduced padding to prevent overflow
            duration: const Duration(milliseconds: 300),
            tabBackgroundColor: const Color(0xFF1E88E5), // Unified Active Color
            color: Colors.grey[500],
            tabs: tabs,
            selectedIndex: _selectedIndex,
            onTabChange: (index) => setState(() => _selectedIndex = index),
          ),
        ),
      ),
    );
  }
}

class _AdminMenuPage extends StatelessWidget {
  final bool isSuper;
  final String? role;
  const _AdminMenuPage({required this.isSuper, this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Management Menu"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _menuItem(context, "Earnings & Finance", LineIcons.wallet, Colors.green, isSuper ? const AdminEarningsView() : null),
          
          // GOD MODE: Allow all admins to manage users (add agents)
          _menuItem(context, "Manage Users", LineIcons.userShield, Colors.red, AdminUsersView(isSuper: isSuper)),
          
          // RESTRICTED: Only Super Admins can manage other Admins
          _menuItem(context, "Manage Admins", LineIcons.users, Colors.deepPurple, isSuper ? const AdminManageAdminsView() : null),

          // ALL ADMINS: Moderate Content
          _menuItem(context, "Manage Clips", LineIcons.video, Colors.pink, const AgentClipsPage(isAdmin: true)),

          const Divider(height: 40),
          _menuItem(context, "System Config", LineIcons.cog, Colors.grey, isSuper ? const AdminConfigView() : null),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, String title, IconData icon, Color color, Widget? page) {
     if (page == null && !isSuper) return const SizedBox.shrink(); // Hide restricted
     
     return Card(
       elevation: 0,
       color: color.withOpacity(0.05),
       margin: const EdgeInsets.only(bottom: 16),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       child: ListTile(
         leading: Container(
           padding: const EdgeInsets.all(10),
           decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
           child: Icon(icon, color: color),
         ),
         title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
         trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
         onTap: () {
           if (page != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: page,
              )));
           } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied")));
           }
         },
       ),
     );
  }
}
