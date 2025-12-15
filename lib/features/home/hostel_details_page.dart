import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HostelDetailsPage extends StatefulWidget {
  final Map<String, dynamic> hostel;

  const HostelDetailsPage({super.key, required this.hostel});

  @override
  State<HostelDetailsPage> createState() => _HostelDetailsPageState();
}

class _HostelDetailsPageState extends State<HostelDetailsPage> {
  bool _isBooking = false;
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();

  Future<void> _bookHostel() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please log in to book")));
      return;
    }

    // 1. Request Gender
    String? selectedSex = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Student Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please select your gender for the specific room allocation."),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGenderOption("Male", Icons.male),
                _buildGenderOption("Female", Icons.female),
              ],
            ),
          ],
        ),
      ),
    );

    if (selectedSex == null) return; // User cancelled

    setState(() => _isBooking = true);

    try {
      // Extract Data
      final name = widget.hostel['name'] ?? 'Unknown Hostel';
      final location = widget.hostel['location'] ?? 'Unknown Location';
      final image = widget.hostel['image'] ?? 'https://picsum.photos/500';
      final priceStr = widget.hostel['price']?.toString().replaceAll(',', '') ?? '0';
      final price = double.tryParse(priceStr) ?? 0.0;
      final agentId = widget.hostel['agentId'] ?? ''; // Important for Agent to see it
      final double agentEarnings = widget.hostel['agentPrice'] != null ? (widget.hostel['agentPrice'] as num).toDouble() : (price - 50); // Fallback if old data

      // Create Booking Object
      final bookingData = {
        'hostelId': widget.hostel['id'] ?? 'unknown_id',
        'hostelName': name,
        'location': location,
        'imageUrl': image,
        'price': price, // Full Price User Pays
        'agentPrice': agentEarnings, // What Agent Gets
        'agentId': agentId, // Ensure Agent sees this
        
        // Student Info
        'userName': user.displayName ?? 'Student',
        'userId': user.uid,
        'studentSex': selectedSex,
        
        'checkIn': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        'checkOut': Timestamp.fromDate(DateTime.now().add(const Duration(days: 120))),
        'status': 'PENDING', // Approval Flow
        'bookingDate': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirestoreService().addBooking(user.uid, bookingData);
      
      // Create Notification
      await _firestoreService.createNotification(user.uid, "Booking Requested", "Your request for $name is pending agent approval.");

      if (mounted) {
        // Updated Success Message
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Request Sent"),
            content: const Text("Your booking request has been sent to the agent. You will be notified once approved."),
            actions: [
               TextButton(onPressed: () {
                 Navigator.pop(context); // Close dialog
                 Navigator.pop(context); // Close page
               }, child: const Text("OK"))
            ],
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _buildGenderOption(String label, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.blue),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(bool isLiked) async {
    final user = _auth.currentUser;
    final hostelId = widget.hostel['id'];
    if (user == null || hostelId == null) return;

    await _firestoreService.toggleFavorite(user.uid, hostelId, isLiked);
  }

  Future<void> _openDirections() async {
    final name = widget.hostel['name']?.toString() ?? '';
    final location = widget.hostel['location']?.toString() ?? '';
    if (location.isEmpty) return;

    final query = Uri.encodeComponent("$name $location");
    final url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$query");

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    // Safely extract data
    final name = widget.hostel['name']?.toString() ?? 'Hostel Details';
    final location = widget.hostel['location']?.toString() ?? 'Unknown Location';
    final price = widget.hostel['price']?.toString() ?? '0';
    final rating = widget.hostel['rating']?.toString() ?? '4.5';
    final capacity = widget.hostel['capacity']?.toString() ?? '4'; // New
    final image = widget.hostel['image']?.toString() ?? 'https://picsum.photos/500/400';
    final hostelId = widget.hostel['id']?.toString();
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. IMMERSIVE PARALLAX HEADER
              SliverAppBar(
                expandedHeight: 350.0,
                pinned: true,
                stretch: true,
                backgroundColor: scaffoldColor,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: user != null ? _firestoreService.getUserData(user.uid) : const Stream.empty(),
                      builder: (context, snapshot) {
                        bool isLiked = false;
                        if (snapshot.hasData && snapshot.data!.exists && hostelId != null) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          final favorites = List.from(data['favorites'] ?? []);
                          isLiked = favorites.contains(hostelId);
                        }

                        return IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : textColor,
                          ),
                          onPressed: () => _toggleLike(isLiked),
                        );
                      }
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.error)),
                      ),
                      // Gradient for text readability
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. CONTENT BODY
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2, color: textColor),
                            ),
                          ),
                          const SizedBox(width: 16), // Add spacing
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("124 reviews", style: TextStyle(color: textColor?.withValues(alpha: 0.6), fontSize: 12)),
                              const SizedBox(height: 4),
                              if (hostelId != null)
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collectionGroup('bookings').where('hostelId', isEqualTo: hostelId).where('status', isEqualTo: 'CONFIRMED').snapshots(),
                                  builder: (context, snapshot) {
                                    final confirmedCount = snapshot.data?.docs.length ?? 0;
                                    final totalCapacity = int.tryParse(capacity) ?? 4;
                                    final spotsLeft = totalCapacity - confirmedCount;
                                    
                                    return Text(
                                      spotsLeft > 0 ? "$spotsLeft / $totalCapacity spots left" : "Fully Booked",
                                      style: TextStyle(
                                        color: spotsLeft > 0 ? primaryColor : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12
                                      ),
                                    );
                                  }
                                )
                              else
                                Text("$capacity / room", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue, size: 18),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(location, 
                              style: TextStyle(fontSize: 16, color: textColor?.withValues(alpha: 0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Directions Button
                          IconButton(
                            icon: const Icon(Icons.directions, color: Colors.blue),
                            onPressed: _openDirections,
                            tooltip: "Get Directions",
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Gallery (Horizontal Scroll)
                      if ((widget.hostel['gallery'] as List?)?.isNotEmpty ?? false) ...[
                        Text("Gallery", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 15),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: (widget.hostel['gallery'] as List).length,
                            itemBuilder: (context, index) {
                              return _buildGalleryImage((widget.hostel['gallery'] as List)[index]);
                            }
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],

                      // Amenities
                      if ((widget.hostel['amenities'] as List?)?.isNotEmpty ?? false) ...[
                        Text("Amenities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 15,
                          runSpacing: 15,
                          children: (widget.hostel['amenities'] as List).map<Widget>((amenity) {
                              IconData icon = FontAwesomeIcons.check;
                              if (amenity == 'WiFi') icon = FontAwesomeIcons.wifi;
                              if (amenity == 'AC') icon = FontAwesomeIcons.snowflake;
                              if (amenity == 'Security') icon = FontAwesomeIcons.shieldHalved;
                              if (amenity == 'Kitchen') icon = FontAwesomeIcons.kitchenSet;
                              if (amenity == 'Transport' || amenity == 'Bus') icon = FontAwesomeIcons.bus;
                              if (amenity == 'Generator') icon = FontAwesomeIcons.bolt;
                              if (amenity == 'Water Flow') icon = FontAwesomeIcons.faucet;
                              if (amenity == 'Study Room') icon = FontAwesomeIcons.bookOpen;
                              
                              return _buildAmenityChip(context, icon, amenity.toString());
                          }).toList(),
                        ),
                        const SizedBox(height: 30),
                      ],

                      const SizedBox(height: 30),

                      // Description
                      Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 10),
                      Text(
                        "Experience the best student living at $name. We offer spacious rooms, high-speed internet, and a study-friendly environment. Located just 5 minutes from the main campus gate, you'll never be late for lectures.",
                        style: TextStyle(fontSize: 15, color: textColor?.withValues(alpha: 0.7), height: 1.5),
                      ),

                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. STICKY BOOKING BAR (The "Real" touch)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Price", style: TextStyle(color: textColor?.withValues(alpha: 0.6), fontSize: 14)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible( // Allow price to shrink if needed
                              child: Text("GHS $price", 
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(" / sem", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor?.withValues(alpha: 0.6))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isBooking ? null : _bookHostel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey[800] : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                    ),
                    child: _isBooking 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Book Now", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildGalleryImage(String url) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        // Replaced with CachedNetworkImage, but for background image we need a different approach
        // Using ImageProvider with CachedNetworkImageProvider
        image: DecorationImage(
          image: CachedNetworkImageProvider(url), 
          fit: BoxFit.cover
        ),
      ),
    );
  }

  Widget _buildAmenityChip(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.white : Colors.blue.shade800),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}
