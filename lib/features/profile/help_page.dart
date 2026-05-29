import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedCategory = "All";
  
  String _whatsappSupport = "";
  String _phoneSupport = "";

  final List<String> _categories = ["All", "Booking", "Payments", "Account", "Safety"];

  @override
  void initState() {
    super.initState();
    _loadSupportContacts();
  }

  Future<void> _loadSupportContacts() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _whatsappSupport = data['student_support']?['whatsapp'] ?? "";
          _phoneSupport = data['admin_contact']?['phone'] ?? data['student_support']?['whatsapp'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error loading support contacts: $e");
    }
  }

  final List<Map<String, dynamic>> _faqs = [
    {
      'q': "How do I secure a room?",
      'a': "Browse hostels, select a room, and tap 'Book Now'. Once you pay the commitment fee, the room is held for you until check-in.",
      'cat': 'Booking'
    },
    {
      'q': "What is the commitment fee?",
      'a': "It is a small percentage of the total rent paid to StayHub to secure your room. The balance is paid directly to the hostel upon arrival.",
      'cat': 'Payments'
    },
    {
      'q': "How do I get a refund?",
      'a': "Refunds are not processed directly through the app. Please contact the StayHub support team or the hostel agent directly to discuss refund eligibility and procedures.",
      'cat': 'Payments'
    },
    {
      'q': "Are the hostels verified?",
      'a': "Yes! Every hostel with a 'Verified' badge has been physically inspected by our team for safety and amenities.",
      'cat': 'Safety'
    },
    {
      'q': "Can I change my room after booking?",
      'a': "Room changes depend on availability. Please message the hostel agent directly via the 'Messages' tab to request a change.",
      'cat': 'Booking'
    },
    {
      'q': "How do I reset my password?",
      'a': "Go to Settings > Change Password, or use the 'Forgot Password' link on the login screen.",
      'cat': 'Account'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. PREMIUM HEADER
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Decorative shapes
                  Positioned(
                    top: -50, right: -50,
                    child: CircleAvatar(radius: 120, backgroundColor: Colors.white.withOpacity(0.1)),
                  ),
                  Positioned(
                    bottom: -30, left: -20,
                    child: CircleAvatar(radius: 80, backgroundColor: Colors.black.withOpacity(0.05)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          "Support Center",
                          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "We're here to help you find your perfect stay.",
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. SEARCH BAR
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search for help topics...",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
            ),
          ),

          // 3. CONTACT OPTIONS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Connect", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildContactButton(
                        context,
                        icon: FontAwesomeIcons.whatsapp,
                        label: "WhatsApp",
                        color: const Color(0xFF25D366),
                        onTap: () {
                          if (_whatsappSupport.isNotEmpty) {
                            _launchURL("https://wa.me/$_whatsappSupport");
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("WhatsApp support unavailable.")));
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildContactButton(
                        context,
                        icon: Icons.headset_mic_rounded,
                        label: "Call Us",
                        color: Colors.blueAccent,
                        onTap: () {
                          if (_phoneSupport.isNotEmpty) {
                            _launchURL("tel:$_phoneSupport");
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone support unavailable.")));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. CATEGORY TABS
          SliverToBoxAdapter(
            child: SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2)),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 5. FAQ LIST
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final filteredFaqs = _faqs.where((f) {
                    final matchesCat = _selectedCategory == "All" || f['cat'] == _selectedCategory;
                    final matchesSearch = _searchQuery.isEmpty || 
                        f['q'].toString().toLowerCase().contains(_searchQuery) || 
                        f['a'].toString().toLowerCase().contains(_searchQuery);
                    return matchesCat && matchesSearch;
                  }).toList();

                  if (index >= filteredFaqs.length) return null;
                  final faq = filteredFaqs[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          faq['q'],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              faq['a'],
                              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _faqs.length,
              ),
            ),
          ),

          // 6. FOOTER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Text(
                    "Can't find what you're looking for?",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _launchURL("mailto:support@stayhubgh.com"),
                    child: Text("Email Support", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "STAYHUB v1.2.0",
                    style: TextStyle(color: Colors.grey.withOpacity(0.3), fontSize: 10, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch application.")),
      );
    }
  }
}