import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = "";

  late AnimationController _bgController;
  late AnimationController _entranceController;

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.payment_rounded, 'label': 'Payments', 'color': Colors.orangeAccent},
    {'icon': Icons.hotel_rounded, 'label': 'Booking', 'color': Colors.blueAccent},
    {'icon': Icons.person_rounded, 'label': 'Account', 'color': Colors.purpleAccent},
    {'icon': Icons.security_rounded, 'label': 'Safety', 'color': Colors.greenAccent},
  ];

  String _selectedCategory = "Payments";

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _launchWhatsApp() async {
    HapticFeedback.heavyImpact();
    String number = "";
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        number = data['student_support']?['whatsapp'] ?? "";
      }
    } catch (_) {}

    if (number.isEmpty) {
      _showSnack("WhatsApp support is currently unavailable.", isError: true);
      return;
    }

    final Uri url = Uri.parse("https://wa.me/$number?text=${Uri.encodeComponent('Hello StayHub Support, I need help with... ')}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail() async {
    HapticFeedback.lightImpact();
    final Uri url = Uri(scheme: 'mailto', path: 'support@stayhubgh.com');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _launchCall() async {
    HapticFeedback.heavyImpact();
    String number = "";
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        number = data['admin_contact']?['phone'] ?? data['student_support']?['whatsapp'] ?? "";
      }
    } catch (_) {}

    if (number.isNotEmpty) {
      final Uri url = Uri.parse("tel:$number");
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeroSection(),
                        const SizedBox(height: 30),
                        _buildSearchBar(),
                        const SizedBox(height: 40),
                        _buildContactCards(),
                        const SizedBox(height: 40),
                        _buildCategoryTabs(),
                        const SizedBox(height: 24),
                        _buildFaqList(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const Text(
            "SUPPORT HUB",
            style: TextStyle(
              color: Colors.white,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 45), // Placeholder for balance
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return _buildAnimatedItem(0, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "How can we\nhelp you today?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Find answers instantly or talk to a concierge.",
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
      ],
    ));
  }

  Widget _buildSearchBar() {
    return _buildAnimatedItem(1, ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search for topics or keywords...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildContactCards() {
    return _buildAnimatedItem(2, Row(
      children: [
        _buildContactCard(
          icon: Icons.message_rounded,
          title: "WhatsApp",
          subtitle: "Instant Help",
          color: const Color(0xFF25D366),
          onTap: _launchWhatsApp,
        ),
        const SizedBox(width: 16),
        _buildContactCard(
          icon: Icons.headset_mic_rounded,
          title: "Hotline",
          subtitle: "Call Agent",
          color: Colors.blueAccent,
          onTap: _launchCall,
        ),
      ],
    ));
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return _buildAnimatedItem(3, SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat['label'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['label']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? cat['color'] : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, size: 18, color: isSelected ? Colors.black : cat['color'] as Color),
                  const SizedBox(width: 8),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ));
  }

  Widget _buildFaqList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getFaqs(),
      builder: (context, snapshot) {
        var faqs = [
          // Fallback Local FAQs categorized
          {'q': "How do I make payment?", 'a': "Go to your booking details and tap 'Pay Now'. We support Mobile Money and Cards.", 'cat': 'Payments'},
          {'q': "When will my booking be confirmed?", 'a': "Agents usually confirm within 2-4 hours. You'll get a notification instantly.", 'cat': 'Booking'},
          {'q': "Can I get a refund?", 'a': "Full automated refunds are available for 24 hours after payment. After that, contact the agent.", 'cat': 'Payments'},
          {'q': "How to update my profile?", 'a': "Go to Profile > Edit Profile to update your name, phone, or avatar.", 'cat': 'Account'},
          {'q': "How do I know a hostel is safe?", 'a': "Every hostel on StayHub is physically verified by our team. Check for the 'Verified' badge.", 'cat': 'Safety'},
        ];

        // Filter by category and search query
        var filteredFaqs = faqs.where((f) {
           final matchesCat = f['cat'] == _selectedCategory;
           final matchesSearch = _searchQuery.isEmpty || f['q']!.toLowerCase().contains(_searchQuery) || f['a']!.toLowerCase().contains(_searchQuery);
           return matchesCat && matchesSearch;
        }).toList();

        if (filteredFaqs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
                  const SizedBox(height: 16),
                  Text("No answers found for this search.", style: TextStyle(color: Colors.white.withOpacity(0.3))),
                ],
              ),
            ),
          );
        }

        return _buildAnimatedItem(4, Column(
          children: filteredFaqs.map((faq) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  iconColor: Colors.blueAccent,
                  collapsedIconColor: Colors.white24,
                  title: Text(
                    faq['q'] as String,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Text(
                        faq['a'] as String,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ));
      },
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            Container(color: const Color(0xFF0F172A)),
            Positioned(
              top: -100 + (_bgController.value * 80),
              left: -50,
              child: _buildBlurBlob(350, Colors.blueAccent.withOpacity(0.2)),
            ),
            Positioned(
              bottom: 100 - (_bgController.value * 60),
              right: -100,
              child: _buildBlurBlob(400, Colors.purpleAccent.withOpacity(0.15)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlurBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 40)]),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.transparent)),
    );
  }

  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entranceController, curve: Interval(index * 0.15, 1.0, curve: Curves.easeOutCubic)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(parent: _entranceController, curve: Interval(index * 0.15, 1.0, curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );
  }
}