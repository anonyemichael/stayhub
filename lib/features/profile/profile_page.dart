import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:stayhub/core/image_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
// For ImageFilter
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/features/profile/help_page.dart'; // Support Page


import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/profile/edit_profile_page.dart';
import 'package:stayhub/features/profile/notifications_settings_page.dart';
import 'package:stayhub/features/profile/settings_page.dart';
import 'package:stayhub/features/profile/wallet_page.dart';
import 'package:stayhub/features/chat/student_inbox_page.dart';
import 'package:stayhub/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/services/local_cache_service.dart';
import 'package:stayhub/core/widgets/skeleton.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/core/widgets/school_logo.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();
  final _firestoreService = FirestoreService();
  final _user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>>? _schoolsCache; // Cache for performance

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _controller.forward();
    _loadCachedProfile();
  }

  Map<String, dynamic>? _cachedProfileData;

  Future<void> _loadCachedProfile() async {
    final cached = await LocalCacheService.load(LocalCacheService.KEY_USER_PROFILE);
    if (cached != null && mounted) {
      setState(() {
        _cachedProfileData = Map<String, dynamic>.from(cached);
      });
    }
    
    // Also load school cache if available
    final cachedSchools = await LocalCacheService.load('cached_schools_list');
    if (cachedSchools != null && mounted) {
      setState(() {
        _schoolsCache = List<Map<String, dynamic>>.from(cachedSchools);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Simplified to only fetch the current user's data from the appropriate collection.
  Stream<DocumentSnapshot> _userStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    // This assumes the AuthGate has already routed the user to the correct dashboard.
    // We can simplify this further by passing the user role, but this is a good first step.
    return FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
  }

  /// Proactively syncs the photoUrl from the Google user object to Firestore if it's missing.
  Future<void> _syncGooglePhotoUrl(Map<String, dynamic> firestoreData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.photoURL != null && user.photoURL!.isNotEmpty) {
      final currentPhoto = firestoreData['photoUrl']?.toString();
      if (currentPhoto == null || currentPhoto.isEmpty) {
        // Sync to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'photoUrl': user.photoURL,
        });
        // Note: The StreamBuilder will automatically pick up this change and update the UI.
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role'); // Clear the cached role
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: MediaQuery.of(context).size.width <= 900 ? AppBar(
        title: Text("Profile", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userStream(),
            builder: (context, snapshot) {
              final data = snapshot.hasData 
                  ? snapshot.data?.data() as Map<String, dynamic>? ?? {}
                  : _cachedProfileData ?? {};

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && data.isEmpty) {
                return _buildSkeletonLoader();
              }

              // Update cache when we get fresh data
              if (snapshot.hasData && snapshot.data?.data() != null) {
                final freshData = snapshot.data!.data() as Map<String, dynamic>;
                LocalCacheService.save(LocalCacheService.KEY_USER_PROFILE, freshData);
                
                // Proactively sync photoUrl from Google if missing in Firestore
                _syncGooglePhotoUrl(freshData);
              }

              final screenWidth = MediaQuery.of(context).size.width;

              if (screenWidth > 900) {
                 return _buildDesktopLayout(context, data, isDark, cardColor, textColor, secondaryTextColor);
              }

              return SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 140), // Increased bottom padding for floating nav bar
                child: Column(
                  children: [
                    _buildProfileCard(data, isDark, cardColor, textColor, secondaryTextColor),
                    const SizedBox(height: 30),
                    _buildMenuComponents(context, isDark, cardColor, textColor, secondaryTextColor),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Map<String, dynamic> data, bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Profile Card
          SizedBox(
            width: 380,
            child: _buildProfileCard(data, isDark, cardColor, textColor, secondaryTextColor),
          ),
          const SizedBox(width: 40),
          // Right Column: Menus
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 40),
              child: _buildMenuComponents(context, isDark, cardColor, textColor, secondaryTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data, bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              border: Border.all(color: Colors.cyanAccent, width: 2),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.indigo,
              backgroundImage: data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty 
                ? CachedNetworkImageProvider(ImageUtils.getSecureUrl(data['photoUrl'])) 
                : null,
              child: (data['photoUrl'] == null || data['photoUrl'].toString().isEmpty)
                ? Text((data['name'] ?? "S")[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))
                : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(data['name'] ?? "Anonye Michael", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(data['email'] ?? "anonyemichael6@gmail.com", style: TextStyle(color: secondaryTextColor, fontSize: 14)),
          const SizedBox(height: 12),
          if (data['school'] != null && data['school'].toString().isNotEmpty)
             _buildSchoolBadge(data['school']),
          const SizedBox(height: 30),
          _buildStatsRow(data, isDark, cardColor, textColor, secondaryTextColor),
        ],
      ),
    );
  }

  Widget _buildSchoolBadge(String schoolName) {
    if (_schoolsCache != null) return _renderSchoolBadge(schoolName);

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('schools').get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && _schoolsCache == null) {
          _schoolsCache = snapshot.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();
          LocalCacheService.save('cached_schools_list', _schoolsCache);
        }
        return _renderSchoolBadge(schoolName);
      },
    );
  }

  Widget _renderSchoolBadge(String schoolName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, String> fetchedLogos = {};
    if (_schoolsCache != null) {
      for (final data in _schoolsCache!) {
        final name = (data['name'] ?? '').toString();
        final logo = (data['logo_url'] ?? data['logo'] ?? '').toString();
        if (name.isNotEmpty && logo.isNotEmpty) {
           fetchedLogos[name.toUpperCase()] = logo;
        }
      }
    }

    final String? logoUrl = SchoolUtils.getSchoolLogo(schoolName, fetchedLogos);
    final String displayName = schoolName; // Use the provided school name for display

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty) ...[
            ClipOval(
              child: SchoolLogo(
                logoUrl: logoUrl,
                size: 24,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Icon(Icons.school, size: 16, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 6),
          ],
          Text(
            displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data, bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).collection('bookings').snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _buildStat(count.toString(), "Bookings", textColor, secondaryTextColor);
            }
          ),
          Container(height: 30, width: 1, color: isDark ? Colors.white24 : Colors.grey[300]),
          _buildStat(data['rating']?.toString() ?? "5.0", "Rating", textColor, secondaryTextColor),
          Container(height: 30, width: 1, color: isDark ? Colors.white24 : Colors.grey[300]),
          Builder(builder: (context) {
             final createdAt = data['createdAt'] as Timestamp?;
             final years = createdAt != null 
                 ? (DateTime.now().difference(createdAt.toDate()).inDays / 365).floor() + 1
                 : 1;
             return _buildStat(years.toString(), "Years", textColor, secondaryTextColor);
          }),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color textColor, Color secondaryTextColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
      ],
    );
  }

  Widget _buildMenuComponents(BuildContext context, bool isDark, Color cardColor, Color textColor, Color secondaryTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("ACCOUNT"),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _buildNavTile(title: "Edit Profile", icon: Icons.person, iconColor: Colors.grey[400]!, textColor: textColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()))),
              _buildDivider(isDark),
              _buildNavTile(
                title: "Messages", 
                icon: Icons.message_outlined, 
                iconColor: Colors.grey[400]!, 
                textColor: textColor, 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentInboxPage())),
                trailing: StreamBuilder<int>(
                  stream: _user != null ? _firestoreService.getTotalUnreadCount(_user!.uid) : Stream.value(0),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("GENERAL"),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _buildNavTile(title: "Settings", icon: Icons.settings_outlined, iconColor: Colors.grey[400]!, textColor: textColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildLogoutButton(context),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
    );
  }

  Widget _buildNavTile({required String title, required IconData icon, required Color iconColor, required Color textColor, required VoidCallback onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: textColor))),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, thickness: 0.5, indent: 64, color: isDark ? Colors.grey[800] : Colors.grey[200]);
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleLogout(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: const Center(
          child: Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Skeleton(height: 300, width: double.infinity, borderRadius: 32),
          const SizedBox(height: 30),
          const Skeleton(height: 80, width: double.infinity, borderRadius: 16),
          const SizedBox(height: 15),
          const Skeleton(height: 80, width: double.infinity, borderRadius: 16),
        ],
      ),
    );
  }
}
