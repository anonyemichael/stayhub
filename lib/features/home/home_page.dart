import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carousel_slider/carousel_slider.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchUserSchool();
  }

  Future<void> _fetchUserSchool() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _userSchool = doc.data()?['school'];
          });
        }
      } catch (e) {
        debugPrint("Error fetching user school: $e");
      }
    }
  }

  final List<String> _categories = [
    "All",
    "My School 🎓",
    "UENR",
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
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryList(
                      categories: _categories,
                      selectedIndex: _selectedCategoryIndex,
                      onChanged: (index) => setState(() => _selectedCategoryIndex = index),
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
                    return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.7, 
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
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Colors.deepPurple.shade800], begin: Alignment.topLeft, end: Alignment.bottomRight))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
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

  String _getGreeting() {
    final now = DateTime.now();
    if (now.month == 12 && (now.day >= 24 && now.day <= 26)) {
      return "Merry Christmas 🎄,";
    } else if ((now.month == 12 && now.day == 31) || (now.month == 1 && now.day == 1)) {
      return "Happy New Year 🎉,";
    } else if (now.month == 2 && now.day == 14) {
      return "Happy Valentines ❤️,";
    } else {
      final hour = now.hour;
      if (hour < 12) return "Good Morning 🌤️,";
      if (hour < 17) return "Good Afternoon ☀️,";
      return "Good Evening 🌙,";
    }
  }

  Widget _buildAppBarHeader() {
    final greeting = _getGreeting();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              const Text("Find your stay", 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: _showSupportOptions,
              icon: const Icon(Icons.headset_mic_outlined, color: Colors.white),
              tooltip: "Support",
            ),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())), 
              icon: const Icon(Icons.notifications_none, color: Colors.white)
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
            decoration: InputDecoration(
              hintText: "Search hostels...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = "");
              }) : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Filter Button
        GestureDetector(
          onTap: _showFilterModal,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.tune, color: Theme.of(context).primaryColor),
          ),
        ),
      ],
    );
  }



  Widget _buildFeaturedCarousel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getFeaturedHostels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: _getSecureUrl(data['image']), 
                fit: BoxFit.cover,
                memCacheWidth: 1000,
                placeholder: (c,u) => Container(color: Colors.grey[200]),
                errorWidget: (c,u,e) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image)),
              ),
              Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(8)),
                      child: const Text("FEATURED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Text(data['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(data['location'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
      stream: _firestoreService.getHostels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
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
                height: 310,
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
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // 1. Search Filter
      if (_searchQuery.isNotEmpty) {
        final name = (data['name'] as String? ?? '').toLowerCase();
        final location = (data['location'] as String? ?? '').toLowerCase();
        if (!name.contains(_searchQuery) && !location.contains(_searchQuery)) {
           return false;
        }
      }

      // 2. Advanced Filters
      // Price
      if (_priceRange != null) {
        final rawPrice = data['price'];
        double price = 0.0;
        if (rawPrice is num) price = rawPrice.toDouble();
        if (rawPrice is String) price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0.0;
        
        if (price < _priceRange!.start || price > _priceRange!.end) {
          return false;
        }
      }

      // Amenities
      if (_filterAmenities.isNotEmpty) {
        final amenities = List<String>.from(data['amenities'] ?? []);
        bool hasAll = true;
        for (var filter in _filterAmenities) {
          if (!amenities.contains(filter)) {
            hasAll = false;
            break;
          }
        }
        if (!hasAll) return false;
      }

      // 3. Category Filter
      final category = _categories[_selectedCategoryIndex];
      
      if (category == "All") return true;

      if (category == "My School 🎓") {
        if (_userSchool == null) return true; // Show all if no school set (or handle empty) -> lets show all essentially acting like "All" but ideally we should prompt. For now, filter loose.
        
        final school = data['school'] as String?;
        if (school != null && school == _userSchool) return true;
        
        // Fallback: Check location string
        final loc = (data['location'] as String? ?? '').toLowerCase();
        return loc.contains(_userSchool!.toLowerCase());
      }
      
      if (category == "UENR" || category == "UDS") {
         final school = data['school'] as String?;
         if (school == category) return true;
         
         // Fallback
         final loc = (data['location'] as String? ?? '').toLowerCase();
         return loc.contains(category.toLowerCase());
      }

      if (category == "Luxury") {
        final rawPrice = data['price'];
        double price = 0.0;
        if (rawPrice is num) price = rawPrice.toDouble();
        if (rawPrice is String) price = double.tryParse(rawPrice.replaceAll(',', '')) ?? 0.0;
        final amenities = List<String>.from(data['amenities'] ?? []);
        bool hasPremium = amenities.contains('AC') && amenities.contains('Fridge');
        return price >= 5000 || hasPremium;
      }
      
      // Removed "AC Rooms" explicit category check as it was dynamic, now generally checking amenities
      return (data['amenities'] as List<dynamic>? ?? []).contains(category);
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
    final bool isFull = (data['isFull'] ?? false) || (data['capacity'] ?? 0) == 0; 
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: data))),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(16),
          // ... (rest of decoration)
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
            // Image section - Fixed height for stability
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), 
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: _getSecureUrl(data['image']), 
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (c,u) => Container(height: 150, color: Colors.grey[200]),
                    errorWidget: (c,u,e) => Container(height: 150, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                  // ... (rest of stack children: Rating, Status, Price)
                  // Rating pill
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
                  // Status badge
                  if (isFull)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: const Text("FULL", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // Price tag
                  Positioned(
                    bottom: 6, right: 6,
                    child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                       decoration: BoxDecoration(
                         color: Theme.of(context).primaryColor,
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                        "GHS ${data['price'] ?? '0'}", 
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name
                    Text(
                      data['name'] ?? '', 
                      style: TextStyle(
                        fontWeight: FontWeight.w600, 
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ), 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis
                    ),
                    // Location
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 11, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            data['location'] ?? 'Unknown', 
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          )
                        )
                      ]
                    ),
                  ],
                ),
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

  const _CategoryList({
    required this.categories,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: isSelected 
                    ? [BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5))]
                    : [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 5)],
                border: isSelected ? null : Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Text(
                categories[index], 
                style: TextStyle(
                  color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), 
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5
                )
              ),
            ),
          );
        }),
      ),
    );
  }
}


