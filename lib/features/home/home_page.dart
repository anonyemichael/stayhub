import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:stayhub/features/home/notifications_page.dart';

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

  final List<String> _categories = [
    "All",
    "Near Campus",
    "Affordable",
    "Luxury",
    "AC Rooms"
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryList(),
                const SizedBox(height: 25),
                if (_searchQuery.isEmpty) ...[
                  _buildSectionHeader("Featured Stays 🔥"),
                  const SizedBox(height: 15),
                  _buildFeaturedCarousel(),
                  const SizedBox(height: 30),
                ],
                _buildSectionHeader(_searchQuery.isEmpty ? "Popular Hostels" : "Search Results", showSeeAll: _searchQuery.isEmpty),
                const SizedBox(height: 15),
                _buildPopularList(),
              ],
            ),
          ),
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
            Text("See All", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
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

  Widget _buildAppBarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Good Morning, 👋", style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 4),
            Text("Find your stay", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())), icon: const Icon(Icons.notifications_none, color: Colors.white)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
      decoration: InputDecoration(
        hintText: "Search hostels, areas...",
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
          _searchController.clear();
          setState(() => _searchQuery = "");
        }) : null,
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        children: List.generate(_categories.length, (index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(_categories[index], style: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.bold)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeaturedCarousel() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getFeaturedHostels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return CarouselSlider(
          options: CarouselOptions(height: 200, enlargeCenterPage: true, autoPlay: true),
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
              CachedNetworkImage(imageUrl: data['image'] ?? '', fit: BoxFit.cover),
              Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(data['location'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularList() {
    return SizedBox(
      height: 260,
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getHostels(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data?.docs ?? [];

          docs = _filterHostels(docs);

          if (docs.isEmpty) return Center(child: Text("No hostels found"));

          return ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 10),
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildPopularCard(docs[index].data() as Map<String, dynamic>..['id'] = docs[index].id),
          );
        },
      ),
    );
  }

  List<QueryDocumentSnapshot<Object?>> _filterHostels(List<QueryDocumentSnapshot<Object?>> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_searchQuery.isNotEmpty && !(data['name'] as String? ?? '').toLowerCase().contains(_searchQuery)) {
        return false;
      }
      final category = _categories[_selectedCategoryIndex];
      if (category != "All") {
        // Simplified category logic - expand as needed
        return (data['amenities'] as List<dynamic>? ?? []).contains(category.replaceAll(' Rooms', ''));
      }
      return true;
    }).toList();
  }

  Widget _buildPopularCard(Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: data))),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 15, bottom: 10),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: CachedNetworkImage(imageUrl: data['image'] ?? '', height: 140, width: double.infinity, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [const Icon(Icons.location_on, size: 14), Expanded(child: Text(" ${data['location'] ?? ''}", style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Fix: Wrapped in Flexible to prevent overflow
                      Flexible(
                        child: Text("GHS ${data['price'] ?? '0'}", style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor, fontSize: 14), overflow: TextOverflow.ellipsis),
                      ),
                      Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), Text(" ${data['rating'] ?? 'N/A'}")]),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
