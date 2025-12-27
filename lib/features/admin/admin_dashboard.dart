import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:stayhub/features/admin/views/admin_stats_view.dart';
import 'package:stayhub/features/admin/views/admin_users_view.dart';
import 'package:stayhub/features/admin/views/admin_earnings_view.dart';
import 'package:stayhub/features/admin/views/admin_hostels_view.dart';
import 'package:stayhub/features/admin/views/admin_config_view.dart';
import 'package:stayhub/features/admin/views/admin_bookings_view.dart';
import 'package:stayhub/features/profile/settings_page.dart';  // Reusing Settings for now

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // Converted to getter to allow passing callbacks to children
  List<Widget> get _pages => [
    const AdminStatsView(),
    const AdminBookingsView(), // Global Booking Management (Replaces Users)
    const AdminHostelsView(),
    const AdminEarningsView(), 
    const AdminConfigView(), 
    const SettingsPage(), // Placeholder profile (No tab for this yet, accessed potentially via other means?)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(blurRadius: 20, color: Colors.black.withValues(alpha: 0.1)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8), 
          child: GNav(
            rippleColor: Colors.grey[300]!,
            hoverColor: Colors.grey[100]!,
            gap: 3, 
            activeColor: const Color(0xFF1E88E5), // Admin Blue
            iconSize: 24,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8), // Tight fit
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: Colors.blue.withValues(alpha: 0.1),
            color: Colors.grey[600],
            tabs: [
              GButton(icon: LineIcons.pieChart, text: _selectedIndex == 0 ? 'Stats' : ''),
              GButton(icon: LineIcons.book, text: _selectedIndex == 1 ? 'Bookings' : ''),
              GButton(icon: LineIcons.building, text: _selectedIndex == 2 ? 'Hostels' : ''),
              GButton(icon: LineIcons.wallet, text: _selectedIndex == 3 ? 'Earn' : ''), 
              GButton(icon: LineIcons.cog, text: _selectedIndex == 4 ? 'Config' : ''),
            ],
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
