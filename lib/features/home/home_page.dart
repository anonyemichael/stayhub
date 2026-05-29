import 'package:flutter/material.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:stayhub/features/home/notifications_page.dart';
import 'package:stayhub/features/home/all_hostels_page.dart';
import 'package:stayhub/features/home/widgets/advanced_filter_modal.dart';
import 'package:stayhub/features/home/widgets/hostel_horizontal_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stayhub/features/map/map_page.dart';
import 'package:stayhub/features/chat/chat_inbox_page.dart';
import 'package:stayhub/services/notification_service.dart';
import 'package:stayhub/services/app_config_service.dart';
import 'package:stayhub/services/local_cache_service.dart';
import 'package:stayhub/core/image_utils.dart';
import 'package:stayhub/core/widgets/school_logo.dart';
import 'package:stayhub/core/widgets/skeleton.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;
  String _searchQuery = "";
  String? _userSchool;
  
  // Advanced Filter State
  RangeValues? _priceRange;
  List<String> _filterAmenities = [];
  
  Map<String, String> _schoolLogos = {};

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _fetchUserSchool();
    _loadDynamicCategories();
  }

  Future<void> _loadCachedData() async {
    // Load User info from cache
    final cachedProfile = await LocalCacheService.load(LocalCacheService.KEY_USER_PROFILE);
    if (cachedProfile != null && mounted) {
      setState(() {
        _userName = cachedProfile['name'] ?? "";
        _userSchool = cachedProfile['school'];
      });
    }

    // Load Categories from cache
    final cachedCats = await LocalCacheService.load(LocalCacheService.KEY_CATEGORIES);
    if (cachedCats != null && mounted) {
      setState(() {
        _categories.clear();
        _categories.addAll(List<String>.from(cachedCats));
      });
    }
  }

  Future<void> _loadDynamicCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('schools').where('isActive', isEqualTo: true).get();
      final List<Map<String, dynamic>> schoolsData = snapshot.docs.map((d) => d.data()).toList();
      
      final List<String> dynSchools = schoolsData.map((s) => s['name'].toString()).toList();
      
      final Map<String, String> fetchedLogos = {};
      for (var s in schoolsData) {
        if (s['logo_url'] != null && s['logo_url'].toString().isNotEmpty) {
           fetchedLogos[s['name'].toString().toUpperCase()] = s['logo_url'].toString();
        }
      }

      final List<String> newCategories = ["All", "My School 🎓"];
      
      // Major schools should always be at the front
      final List<String> majorSchools = ["UENR", "KNUST", "UG"];
      newCategories.addAll(majorSchools);
      
      // Add any additional schools from Firestore (excluding duplicates)
      newCategories.addAll(dynSchools.where((s) => !majorSchools.contains(s.toUpperCase())));
      
      newCategories.addAll(["Affordable", "Luxury"]);

      if (mounted) {
        setState(() {
          _schoolLogos = fetchedLogos;
          _categories.clear();
          _categories.addAll(newCategories);
        });
      }
      
      // Save to cache
      await LocalCacheService.save(LocalCacheService.KEY_CATEGORIES, newCategories);
    } catch (e) {
      debugPrint("Error loading categories: $e");
    }
  }

  Future<void> _fetchUserSchool() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          final data = doc.data()!;
          setState(() {
            _userSchool = data['school'];
            _userName = data['name'] ?? user.displayName ?? "Student";
          });
          // Cache it
          await LocalCacheService.save(LocalCacheService.KEY_USER_PROFILE, {
            'name': _userName,
            'school': _userSchool,
          });
        }
      } catch (e) {
        debugPrint("Error fetching user school: $e");
      }
    }
  }

  String _userName = "";

  final List<String> _categories = [
    "All",
    "My School 🎓",
    "UENR",
    "KNUST",
    "UG",
    "CUG",
    "UDS",
    "Affordable",
    "Luxury",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Use platform defaults for better performance
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 25),
                    _CategoryList(
                      categories: _categories,
                      selectedIndex: _selectedCategoryIndex,
                      onChanged: (index) => setState(() => _selectedCategoryIndex = index),
                      schoolLogos: _schoolLogos,
                    ),
                    const SizedBox(height: 25),
                    
                    // Show Dynamic Layout ONLY if not searching
                    if (_searchQuery.isEmpty) ...[
                      // 1. Featured Carousel
                      _buildSectionHeader("Featured Stays 🔥"),
                      const SizedBox(height: 15),
                      _buildFeaturedCarousel(),
                      const SizedBox(height: 30),
    
                      // 2. Trending / Horizontal List
                      _buildSectionHeader("Trending Near You"),
                      const SizedBox(height: 15),
                      _buildHorizontalList(), 
                      const SizedBox(height: 30),
                    ],
    
                    // 3. Main Grid / Search Results
                    _buildSectionHeader(
                      _searchQuery.isEmpty ? "All Hostels" : "Search Results", 
                      showSeeAll: _searchQuery.isEmpty
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
              
              // Vertical Grid of Hostels
              StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getHostels(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: (MediaQuery.of(context).size.width / 220).floor().clamp(2, 5),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: MediaQuery.of(context).size.width < 400 ? 0.65 : 0.68,
                        ),
                        delegate: SliverChildListDelegate(
                          List.generate(6, (index) => const HostelSkeleton()),
                        ),
                      ),
                    );
                  }
                  
                  var docs = snapshot.data?.docs ?? [];
                  docs = _filterHostels(docs);
    
                  if (docs.isEmpty) {
                    return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No hostels found"))));
                  }
    
                  // Responsive Grid
                  final displayDocs = docs.take(20).toList();
                  final screenWidth = MediaQuery.of(context).size.width;
                  // Use width of the constrained box if screen is larger than 1200
                  final effectiveWidth = screenWidth > 1200 ? 1200 : screenWidth;
                  // Calculate columns: Aim for card width ~200-250px
                  final crossAxisCount = (effectiveWidth / 220).floor().clamp(2, 5); 
    
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: screenWidth < 400 ? 0.65 : 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return RepaintBoundary(
                            child: _buildPopularCard(displayDocs[index].data() as Map<String, dynamic>..['id'] = displayDocs[index].id),
                          );
                        },
                        childCount: displayDocs.length,
                      ),
                    ),
                  );
                },
              ),
              
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Quick Support", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                 _buildContactBtn(Icons.call, "Call", Colors.green, () => _launchDynamicContact('phone')),
                 _buildContactBtn(Icons.email, "Email", Colors.red, () => _launchDynamicContact('email')),
                 _buildContactBtn(FontAwesomeIcons.whatsapp, "WhatsApp", Colors.teal, () => _launchDynamicContact('whatsapp')),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDynamicContact(String type) async {
    Navigator.pop(context); // Close modal first
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting..."), duration: Duration(seconds: 1)));
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'support_${type}';
      
      // Try local cache first
      String value = prefs.getString(cacheKey) ?? "";
      
      // Fetch from Firestore in background or if cache empty
      if (value.isEmpty) {
        final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
        final data = doc.data() ?? {};
        final support = data['student_support'] as Map<String, dynamic>? ?? {};
        
        if (type == 'whatsapp') value = support['whatsapp'] ?? "";
        if (type == 'email') value = support['email'] ?? "support@stayhub.app";
        if (type == 'phone') value = support['phone'] ?? support['whatsapp'] ?? ""; 

        if (value.isNotEmpty) {
           await prefs.setString(cacheKey, value);
        }
      }

      if (value.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Contact info not available"), backgroundColor: Colors.red));
         return;
      }

      Uri? uri;
      if (type == 'whatsapp') {
         uri = Uri.parse("https://wa.me/$value?text=${Uri.encodeComponent('Hello StayHub')}");
         await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (type == 'email') {
         uri = Uri(scheme: 'mailto', path: value, query: 'subject=Support Request');
         await launchUrl(uri);
      } else if (type == 'phone') {
         uri = Uri.parse("tel:$value");
         await launchUrl(uri);
      }

    } catch (e) {
      debugPrint("Error launching contact: $e");
    }
  }

  Widget _buildContactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {bool showSeeAll = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (showSeeAll)
             GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllHostelsPage())),
              child: Text("See All", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final expandedHeight = screenWidth < 380 ? 200.0 : 225.0;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).primaryColor, Colors.deepPurple.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  children: [
                    _buildAppBarHeader(),
                    const Spacer(),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolBadgeInline(String schoolName) {
    final String? logoUrl = SchoolUtils.getSchoolLogo(schoolName, _schoolLogos);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty) ...[
            ClipOval(
              child: SchoolLogo(
                logoUrl: logoUrl,
                size: 16,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 4),
          ] else ...[
            ClipOval(child: Image.asset('assets/logo/logo.png', width: 16, height: 16, fit: BoxFit.cover)),
            const SizedBox(width: 4),
          ],
          Text(
            schoolName,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final now = DateTime.now();
    if (now.month == 12 && (now.day >= 24 && now.day <= 26)) {
      return "Merry Christmas 🎄";
    } else if ((now.month == 12 && now.day == 31) || (now.month == 1 && now.day == 1)) {
      return "Happy New Year 🎉";
    } else if (now.month == 2 && now.day == 14) {
      return "Happy Valentines ❤️";
    } else {
      final hour = now.hour;
      if (hour < 12) return "Good Morning 🌤️";
      if (hour < 17) return "Good Afternoon ☀️";
      return "Good Evening 🌙";
    }
  }

  Widget _buildAppBarHeader() {
    final greeting = _getGreeting();
    final screenWidth = MediaQuery.of(context).size.width;
    
    final titleFontSize = screenWidth < 360 ? 20.0 : (screenWidth < 400 ? 24.0 : 28.0);
    final greetingFontSize = screenWidth < 360 ? 12.0 : 14.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting, 
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8), 
                  fontSize: greetingFontSize, 
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _userName.isNotEmpty ? _userName.split(' ')[0] : "Guest",
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: titleFontSize, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_userSchool != null && _userSchool!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildSchoolBadgeInline(_userSchool!),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _showSupportOptions,
              icon: const Icon(Icons.headset_mic_outlined, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Support",
            ),
            StreamBuilder<int>(
              stream: FirebaseAuth.instance.currentUser != null 
                  ? _firestoreService.getTotalUnreadCount(FirebaseAuth.instance.currentUser!.uid) 
                  : Stream.value(0),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatInboxPage())),
                  icon: Badge(
                    label: Text(count.toString()),
                    isLabelVisible: count > 0,
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Messages",
                );
              },
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())), 
              icon: StreamBuilder<int>(
                stream: FirebaseAuth.instance.currentUser != null 
                    ? NotificationService().getUnreadNotificationCount(FirebaseAuth.instance.currentUser!.uid) 
                    : Stream.value(0),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Badge(
                    label: Text(count.toString()),
                    isLabelVisible: count > 0,
                    child: const Icon(Icons.notifications_none, color: Colors.white),
                  );
                },
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedFilterModal(
        currentFilters: {
          'priceRange': _priceRange,
          'amenities': _filterAmenities,
        },
        onApply: (filters) {
          setState(() {
            _priceRange = filters['priceRange'];
            _filterAmenities = filters['amenities'];
          });
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: "Search hostels or locations...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).primaryColor),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = "");
                }) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.withOpacity(0.2),
          ),
          IconButton(
            onPressed: _showFilterModal,
            icon: Icon(Icons.tune_rounded, color: Theme.of(context).primaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 15),
          ),
        ],
      ),
    );
  }



  Widget _buildFeaturedCarousel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getFeaturedHostels(limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData && _searchQuery.isEmpty) {
          return const FeaturedSkeleton();
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        return CarouselSlider(
          options: CarouselOptions(
            height: 220, 
            enlargeCenterPage: true, 
            autoPlay: true,
                      viewportFraction: screenWidth > 900 ? 0.35 : 0.85, 
                    ),
                    items: docs.map((doc) => _buildFeaturedCard(doc.data() as Map<String, dynamic>..['id'] = doc.id)).toList(),
        );
      },
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: ImageUtils.getSecureUrl(data['image']), 
                fit: BoxFit.cover,
                memCacheWidth: 500,
                placeholder: (c,u) => Container(color: Colors.grey[200]),
                errorWidget: (c,u,e) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor, 
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                      ),
                      child: const Text("FEATURED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['name'] ?? '', 
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.white.withOpacity(0.7), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['location'] ?? '', 
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getTrendingHostels(limit: 8),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              itemBuilder: (_, __) => const HostelSkeleton(),
            ),
          );
        }
        var docs = snapshot.data?.docs ?? [];
        docs = docs.take(6).toList(); // Show 6 items for grid balance

        if (docs.isEmpty) return const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
             final screenWidth = MediaQuery.of(context).size.width;
             if (screenWidth > 900) {
                // Desktop: Grid Layout (Creative & Fit)
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.start,
                    children: docs.map((doc) {
                       return HostelHorizontalCard(data: doc.data() as Map<String, dynamic>..['id'] = doc.id);
                    }).toList(),
                  ),
                );
             }

             // Mobile: Horizontal List
             return SizedBox(
                height: 255,
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 10),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => HostelHorizontalCard(data: docs[index].data() as Map<String, dynamic>..['id'] = docs[index].id),
                ),
             );
          }
        );
      },
    );
  }

  List<QueryDocumentSnapshot<Object?>> _filterHostels(List<QueryDocumentSnapshot<Object?>> docs) {
    if (_searchQuery.isEmpty && _priceRange == null && _filterAmenities.isEmpty && _selectedCategoryIndex == 0) {
      return docs;
    }

    final category = _categories[_selectedCategoryIndex];
    final searchQueryLower = _searchQuery.toLowerCase().trim();

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // 1. Search Filter
      if (searchQueryLower.isNotEmpty) {
        final name = (data['name'] as String? ?? '').toLowerCase();
        final location = (data['location'] as String? ?? '').toLowerCase();
        if (!name.contains(searchQueryLower) && !location.contains(searchQueryLower)) {
           return false;
        }
      }

      // 2. Advanced Filters
      // Price
      if (_priceRange != null) {
        final rawPrice = data['price'];
        double price = 0.0;
        if (rawPrice is num) {
          price = rawPrice.toDouble();
        } else if (rawPrice is String) {
          price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0.0;
        }
        
        if (price < _priceRange!.start || price > _priceRange!.end) {
          return false;
        }
      }

      // Amenities
      if (_filterAmenities.isNotEmpty) {
        final amenities = (data['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        for (var filter in _filterAmenities) {
          if (!amenities.contains(filter)) return false;
        }
      }

      // 3. Category Filter
      if (category == "All") return true;

      if (category == "My School 🎓") {
        if (_userSchool == null) return true;
        final school = (data['school'] as String? ?? '').toLowerCase();
        if (school == _userSchool!.toLowerCase()) return true;
        
        final loc = (data['location'] as String? ?? '').toLowerCase();
        return loc.contains(_userSchool!.toLowerCase());
      }
      
      final categoryLower = category.toLowerCase();
      if (category == "UENR" || category == "CUG" || category == "UDS") {
         final school = (data['school'] as String? ?? '').toLowerCase();
         if (school == categoryLower) return true;
         
         final loc = (data['location'] as String? ?? '').toLowerCase();
         return loc.contains(categoryLower);
      }

      if (category == "Luxury") {
        final rawPrice = data['price'];
        double price = 0.0;
        if (rawPrice is num) price = rawPrice.toDouble();
        else if (rawPrice is String) price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0.0;
        
        final amenities = (data['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        bool hasPremium = amenities.contains('AC') && amenities.contains('Fridge');
        return price >= 5000 || hasPremium;
      }

      if (category == "Affordable") {
        final rawPrice = data['price'];
        double price = 0.0;
        if (rawPrice is num) price = rawPrice.toDouble();
        else if (rawPrice is String) price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0.0;
        return price < 3000;
      }
      
      final amenities = (data['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      return amenities.contains(category);
    }).toList();
  }

  String _getSecureUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    // Force HTTPS
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  Widget _buildPopularCard(Map<String, dynamic> data) {
    final List<dynamic> rooms = data['rooms'] ?? [];
    double minPrice = 0;
    double maxPrice = 0;
    int totalSlots = 0;
    const double commission = 100.0;

    if (rooms.isNotEmpty) {
      final prices = rooms.map((r) => ((r['price'] as num? ?? 0).toDouble() * 1.10)).toList();
      prices.sort();
      minPrice = prices.first;
      maxPrice = prices.last;
      for (var r in rooms) {
        totalSlots += (r['available'] as num? ?? 0).toInt();
      }
    } else {
      final basePrice = (data['price'] is num) ? (data['price'] as num).toDouble() : (double.tryParse(data['price']?.toString() ?? '0') ?? 0.0);
      minPrice = basePrice * 1.10;
      maxPrice = minPrice;
      
      final rawCap = data['capacity'];
      if (rawCap is num) {
        totalSlots = rawCap.toInt();
      } else {
        totalSlots = int.tryParse(rawCap?.toString() ?? '0') ?? 0;
      }
    }

    final bool isFull = (data['isFull'] ?? false) || totalSlots <= 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: data))),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(
               color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1), 
               blurRadius: 8, 
               offset: const Offset(0, 3)
             )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), 
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: ImageUtils.getSecureUrl(data['image']), 
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (c,u) => Container(height: 150, color: Colors.grey[200]),
                    errorWidget: (c,u,e) => Container(height: 150, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 10),
                          const SizedBox(width: 2),
                          Text("${data['rating'] ?? '4.5'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  if (isFull)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: const Text("FULL", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Positioned(
                    bottom: 6, right: 6,
                    child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                       decoration: BoxDecoration(
                         color: Theme.of(context).primaryColor,
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                        minPrice == maxPrice 
                          ? "GHS ${minPrice.toStringAsFixed(0)}" 
                          : "GHS ${minPrice.toStringAsFixed(0)}+", 
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details section
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    data['name'] ?? '', 
                    style: TextStyle(
                      fontWeight: FontWeight.w600, 
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 2),
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 10, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          data['location'] ?? 'Unknown', 
                          style: TextStyle(fontSize: 9, color: Colors.grey[600]), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        )
                      ),
                      Text(
                        isFull ? "FULL" : "$totalSlots left",
                        style: TextStyle(fontSize: 8, color: isFull ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ]
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Map<String, String> schoolLogos;

  const _CategoryList({
    required this.categories,
    required this.selectedIndex,
    required this.onChanged,
    required this.schoolLogos,
  });

  Widget _buildCategoryIcon(BuildContext context, String category, bool isSelected) {
    final iconColor = isSelected ? Colors.white : Theme.of(context).primaryColor;
    
    if (category == "All") return Icon(Icons.grid_view_rounded, size: 18, color: iconColor);
    if (category == "My School 🎓") return Icon(Icons.school_rounded, size: 18, color: iconColor);
    if (category == "Affordable") return Icon(Icons.sell_rounded, size: 18, color: iconColor);
    if (category == "Luxury") return Icon(Icons.diamond_rounded, size: 18, color: iconColor);
    
    final logoUrl = SchoolUtils.getSchoolLogo(category, schoolLogos);
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: SchoolLogo(
            logoUrl: logoUrl,
            size: 22,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: Image.asset('assets/logo/logo.png', width: 14, height: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidePadding = 20.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(left: sidePadding),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(categories.length, (index) {
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: isSelected 
                    ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
                    : [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
                border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCategoryIcon(context, categories[index], isSelected),
                  const SizedBox(width: 8),
                  Text(
                    categories[index], 
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8), 
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3
                    )
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}



