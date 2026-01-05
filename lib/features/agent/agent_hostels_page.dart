import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/agent/add_hostel_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/notification_service.dart';

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
        _isAdmin = adminDoc.exists;
        // Always fetch ALL, then filter in UI to avoid Index Errors
        _hostelsStream = firestoreService.getHostels();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please log in"));
    // If stream is null, we are still loading role
    if (_hostelsStream == null) return const Center(child: CircularProgressIndicator());
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

    return Scaffold(
      backgroundColor: bgColor, 
      body: StreamBuilder<QuerySnapshot>(
        stream: _hostelsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Padding(
               padding: const EdgeInsets.all(20.0),
               child: Text("Error loading properties: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
             ));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final allDocs = snapshot.data!.docs;
          
          // CLIENT-SIDE FILTERING (Temporary Fix for Index Issues)
          final docs = _isAdmin 
              ? allDocs 
              : allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['agentId'] == user!.uid;
                }).toList();

          if (docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // Extra bottom padding for FAB
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildModernHostelCard(context, data, docs[index].id, isDark);
            },
          );
        },
      ),
      floatingActionButton: _buildGradientFAB(context),
    );
  }

  // --- WIDGETS ---

  Widget _buildModernHostelCard(BuildContext context, Map<String, dynamic> data, String docId, bool isDark) {
    // Extract data
    final String imageUrl = data['image'] ?? '';
    final String name = data['name'] ?? 'Unnamed Hostel';
    final String location = data['location'] ?? 'Unknown Location';
    final String price = data['price']?.toString() ?? '0';
    final bool isFeatured = data['isFeatured'] ?? false;
    // Real rating logic
    // Safe Rating Logic
    final dynamic rawRating = data['rating'];
    String rating = "New";
    if (rawRating != null) {
      if (rawRating is num) {
        rating = rawRating.toStringAsFixed(1);
      } else if (rawRating is String) {
        final parsed = double.tryParse(rawRating);
        if (parsed != null) rating = parsed.toStringAsFixed(1);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                    placeholder: (context, url) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
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
                  onTap: () => _showManageHostelSheet(context, docId, data),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.8) : Colors.white, // Opaque for better visibility 
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Icon(Icons.more_horiz_rounded, size: 22, color: isDark ? Colors.white : Colors.black), // More explicit "Menu" icon
                  ),
                ),
              ),

              // ... (rest of the build method) ...



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
                        "GHS $price / sem",
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    // Rating Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1),
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
                    Icon(Icons.location_on, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amenities Row (Mini Icons)
                if (data['amenities'] != null && data['amenities'] is List)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: (data['amenities'] as List).take(4).map((amenity) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              amenity.toString(),
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[300] : Colors.grey[700]),
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.blueGrey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.apartment_rounded, size: 60, color: isDark ? Colors.grey[600] : Colors.blueGrey.shade200),
          ),
          const SizedBox(height: 24),
          Text(
            "No Properties Listed",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            "Add your first hostel to start earning.",
            style: TextStyle(color: isDark ? Colors.white30 : Colors.grey[500]),
          ),
          const SizedBox(height: 32),
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
  void _showManageHostelSheet(BuildContext context, String docId, Map<String, dynamic> data) {
      final bool isFull = data['isFull'] ?? false;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      showModalBottomSheet(
        context: context,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Manage Property", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 20),
                    
                    // Mark as Full Toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.report_problem_rounded, color: isFull ? Colors.red : Colors.grey),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Mark as Fully Booked", 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                                ),
                                Text(
                                  "Prevent new bookings immediately", 
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isFull,
                            activeThumbColor: Colors.red,
                            onChanged: (val) async {
                              // Optimistic Update in Modal
                              setModalState(() {}); // Rebuild modal to show switch change? 
                              // Actually, we should close or show loading.
                              
                              Navigator.pop(context); // Close first
                              
                              try {
                                await FirebaseFirestore.instance.collection('hostels').doc(docId).update({
                                  'isFull': val
                                });

                                // Send Notification
                                await NotificationService().showNotification(
                                  title: 'Property Status Updated',
                                  body: val ? 'Property marked as FULLY BOOKED' : 'Property is now OPEN for bookings',
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(val ? "Property marked as FULL" : "Property is now OPEN"),
                                    backgroundColor: val ? Colors.red : Colors.green,
                                  ));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                }
                              }
                            },
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                     // Placeholder for full edit
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: const Text("Edit Details"),
                      subtitle: const Text("Change name, price, photos..."),
                      onTap: () {
                         Navigator.pop(context);
                         Navigator.push(context, MaterialPageRoute(builder: (_) => AddHostelPage(hostelId: docId, initialData: data)));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text("Delete Property"),
                      onTap: () {
                         // Implement delete confirmation
                         Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            }
          );
        }
      );
  }
}