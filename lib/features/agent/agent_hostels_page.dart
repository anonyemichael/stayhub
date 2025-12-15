import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/agent/add_hostel_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AgentHostelsPage extends StatefulWidget {
  const AgentHostelsPage({super.key});

  @override
  State<AgentHostelsPage> createState() => _AgentHostelsPageState();
}

class _AgentHostelsPageState extends State<AgentHostelsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final firestoreService = FirestoreService();
  Stream<QuerySnapshot>? _hostelsStream;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _determineUserRoleAndSetStream();
  }

  Future<void> _determineUserRoleAndSetStream() async {
    if (user == null) return;
    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(user!.uid).get();

    if (mounted) {
      setState(() {
        _isAdmin = adminDoc.exists;
        _hostelsStream = _isAdmin
            ? firestoreService.getHostels()
            : firestoreService.getAgentHostels(user!.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please log in"));
    // If stream is null, we are still loading role
    if (_hostelsStream == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background makes white cards pop
      body: StreamBuilder<QuerySnapshot>(
        stream: _hostelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // Extra bottom padding for FAB
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildModernHostelCard(context, data, docs[index].id);
            },
          );
        },
      ),
      floatingActionButton: _buildGradientFAB(context),
    );
  }

  // --- WIDGETS ---

  Widget _buildModernHostelCard(BuildContext context, Map<String, dynamic> data, String docId) {
    // Extract data
    final String imageUrl = data['image'] ?? '';
    final String name = data['name'] ?? 'Unnamed Hostel';
    final String location = data['location'] ?? 'Unknown Location';
    final String price = data['price']?.toString() ?? '0';
    final bool isFeatured = data['isFeatured'] ?? false;
    // Real rating logic
    final dynamic rawRating = data['rating'];
    final String rating = rawRating != null ? (rawRating as num).toStringAsFixed(1) : "New";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGE HEADER with Overlays
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Hero(
                  tag: 'hostel_$docId',
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      height: 200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),

              // Top Right: Edit Button
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    // Navigate to Edit Page (To be implemented)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit feature coming next!")));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_outlined, size: 20, color: Colors.black87),
                  ),
                ),
              ),

              // Top Left: Featured Badge (Conditional)
              if (isFeatured)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700), // Gold
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "FEATURED",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),

              // Bottom Left: Glassmorphism Price Tag
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sell_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "₵$price / sem",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. DETAILS SECTION
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Rating Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(rating, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amenities Row (Mini Icons)
                if (data['amenities'] != null)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (data['amenities'] as List<dynamic>).take(4).map((amenity) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              amenity.toString(),
                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.apartment_rounded, size: 60, color: Colors.blueGrey.shade200),
          ),
          const SizedBox(height: 24),
          Text(
            "No Properties Listed",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your first hostel to start earning.",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientFAB(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30), // Pill shape
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)], // Deep Blue Gradient
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.transparent, // Must be transparent to show container gradient
        elevation: 0,
        highlightElevation: 0,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHostelPage()));
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Add Property", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}