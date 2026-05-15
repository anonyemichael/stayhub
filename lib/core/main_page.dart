import 'dart:ui'; // For Glassmorphism blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added
import 'package:stayhub/features/home/home_page.dart';
import 'package:stayhub/features/clips/clips_page.dart';
import 'package:stayhub/features/map/map_page.dart';
import 'package:stayhub/features/bookings/bookings_page.dart';
import 'package:stayhub/features/profile/profile_page.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/map/map_page.dart';
import 'package:stayhub/features/clips/clips_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  final List<bool> _pageLoaded = [true, false, false, false, false];
  final _firestoreService = FirestoreService();
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _checkAnnouncements();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if user is in 'admins' collection
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.email)
          .get();
      if (adminDoc.exists) {
        if (mounted) setState(() => _isAdmin = true);
        return;
      }

      // Also check specific hardcoded super admins
      const superAdmins = ['anonyemichael6@gmail.com', 'admin@stayhub.com'];
      if (user.email != null && superAdmins.contains(user.email)) {
        if (mounted) setState(() => _isAdmin = true);
      }
    }
  }

  Future<void> _checkAnnouncements() async {
    // Check for recent critical announcements (last 24 hours)
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      final query = await FirebaseFirestore.instance
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && mounted) {
        final doc = query.docs.first;
        final docId = doc.id;

        // Check SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final lastSeenId = prefs.getString('last_seen_announcement_id');

        if (lastSeenId == docId) {
          return; // Already seen this specific announcement
        }

        final data = doc.data();
        final title = data['title'] ?? 'Announcement';
        final body = data['body'] ?? '';

        // Show Dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.campaign, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(child: Text(title, overflow: TextOverflow.ellipsis))
            ]),
            content: SingleChildScrollView(child: Text(body)),
            actions: [
              TextButton(
                  onPressed: () {
                    // Mark as seen when dismissed
                    prefs.setString('last_seen_announcement_id', docId);
                    Navigator.pop(context);
                  },
                  child: const Text("Got it"))
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Announcement check failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> pages = [
      const HomePage(),
      _pageLoaded[1]
          ? ClipsPage(isActive: _currentIndex == 1, isAdmin: _isAdmin)
          : const SizedBox.shrink(),
      _pageLoaded[2]
          ? MapPage(isActive: _currentIndex == 2)
          : const SizedBox.shrink(),
      _pageLoaded[3] ? const BookingsPage() : const SizedBox.shrink(),
      _pageLoaded[4] ? const ProfilePage() : const SizedBox.shrink(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom > 0 ? 10 : 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.9)
                            : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                          child: BottomNavigationBar(
                            currentIndex: _currentIndex,
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                            type: BottomNavigationBarType.fixed,
                            selectedItemColor: Theme.of(context).primaryColor,
                            unselectedItemColor:
                                isDark ? Colors.white54 : Colors.grey.shade500,
                            showSelectedLabels: false,
                            showUnselectedLabels: false,
                            items: [
                              BottomNavigationBarItem(
                                icon: FaIcon(FontAwesomeIcons.house, size: 20),
                                activeIcon: FaIcon(
                                    FontAwesomeIcons.houseChimney,
                                    size: 22),
                                label: 'Home',
                              ),
                              BottomNavigationBarItem(
                                icon: const FaIcon(FontAwesomeIcons.play, size: 20),
                                activeIcon: const FaIcon(FontAwesomeIcons.solidCirclePlay, size: 22),
                                label: 'Clips',
                              ),
                              BottomNavigationBarItem(
                                icon: const FaIcon(FontAwesomeIcons.mapLocationDot, size: 20),
                                activeIcon: const FaIcon(FontAwesomeIcons.solidMap, size: 22),
                                label: 'Map',
                              ),
                              const BottomNavigationBarItem(
                                icon: FaIcon(FontAwesomeIcons.bookmark, size: 20),
                                activeIcon: FaIcon(FontAwesomeIcons.solidBookmark, size: 22),
                                label: 'Bookings',
                              ),
                                BottomNavigationBarItem(
                                  icon: const FaIcon(FontAwesomeIcons.user, size: 20),
                                  activeIcon: const FaIcon(FontAwesomeIcons.solidUser, size: 22),
                                  label: 'Profile',
                                ),
                            ],
                            onTap: (index) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _currentIndex = index;
                                _pageLoaded[index] = true;
                              });
                            },
                          ), // BottomNavigationBar
                        ), // Inner Container
                      ), // Outer Container
                    ), // ConstrainedBox
              ), // Flexible
            ], // Row children
          ), // Row
        ), // Padding
      ), // SafeArea
    ); // Scaffold
  }
}
