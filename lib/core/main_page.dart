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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      const HomePage(),
      ClipsPage(isActive: _currentIndex == 1), // Pass active state
      MapPage(isActive: _currentIndex == 2), // Pass active state
      const BookingsPage(),
      ProfilePage(), // Removed const
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
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
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.75)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                elevation: 0,
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Theme.of(context).primaryColor,
                unselectedItemColor: isDark ? Colors.white54 : Colors.grey.shade500,
                showSelectedLabels: false,
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
