import 'dart:ui'; // For Glassmorphism blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:stayhub/features/home/home_page.dart';
import 'package:stayhub/features/clips/clips_page.dart';
import 'package:stayhub/features/map/map_page.dart';
import 'package:stayhub/features/bookings/bookings_page.dart';
import 'package:stayhub/features/profile/profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  // The 5 main screens of the app
  final List<Widget> _pages = [
    const HomePage(),
    const ClipsPage(),
    const MapPage(),
    const BookingsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Check if dark mode is active to adjust glass styling
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Key property: Allows the page content to flow BEHIND the floating nav bar
      extendBody: true,

      body: _pages[_currentIndex],

      bottomNavigationBar: Container(
        // Lift the nav bar up slightly for that "Floating" look
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          // Soft shadow to make it pop off the screen
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            // The Glass Blur Effect
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                // Semi-transparent background
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(30),
                // Subtle white/grey border to define the glass edges
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                elevation: 0,
                backgroundColor: Colors.transparent, // Must be transparent for glass effect
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Theme.of(context).primaryColor,
                unselectedItemColor: isDark ? Colors.white54 : Colors.grey.shade500,
                showSelectedLabels: false, // Clean look (no text)
                showUnselectedLabels: false,
                items: const [
                  BottomNavigationBarItem(
                    icon: FaIcon(FontAwesomeIcons.house, size: 20),
                    activeIcon: FaIcon(FontAwesomeIcons.houseChimney, size: 22),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: FaIcon(FontAwesomeIcons.play, size: 20),
                    activeIcon: FaIcon(FontAwesomeIcons.solidCirclePlay, size: 22),
                    label: 'Clips',
                  ),
                  BottomNavigationBarItem(
                    icon: FaIcon(FontAwesomeIcons.mapLocationDot, size: 20),
                    activeIcon: FaIcon(FontAwesomeIcons.solidMap, size: 22),
                    label: 'Map',
                  ),
                  BottomNavigationBarItem(
                    icon: FaIcon(FontAwesomeIcons.bookmark, size: 20),
                    activeIcon: FaIcon(FontAwesomeIcons.solidBookmark, size: 22),
                    label: 'Bookings',
                  ),
                  BottomNavigationBarItem(
                    icon: FaIcon(FontAwesomeIcons.user, size: 20),
                    activeIcon: FaIcon(FontAwesomeIcons.solidUser, size: 22),
                    label: 'Profile',
                  ),
                ],
                onTap: (index) {
                  // Tactile feedback when clicking tabs
                  HapticFeedback.lightImpact();
                  setState(() => _currentIndex = index);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
