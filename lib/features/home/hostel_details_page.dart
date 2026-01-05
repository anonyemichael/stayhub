import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';
import 'package:stayhub/features/home/widgets/reviews_section.dart';

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
  
  String _getSecureUrl(String? url) {
    if (url == null || url.isEmpty) return 'https://picsum.photos/500'; 
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

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
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: "By booking, you agree to StayHub's ",
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                children: [
                  TextSpan(
                    text: "Terms",
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        Uri.parse('https://stayhubgh.com/terms.html'),
                        mode: LaunchMode.inAppWebView,
                      ),
                  ),
                  const TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        Uri.parse('https://stayhubgh.com/privacy.html'),
                        mode: LaunchMode.inAppWebView,
                      ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
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
      final image = _getSecureUrl(widget.hostel['image']);
      
      // 1. Get Financials (Prefer stored values from AddHostelPage)
      final double studentPaysTotal = (widget.hostel['price'] as num?)?.toDouble() ?? 0.0;
      final agentId = widget.hostel['agentId'] ?? ''; 
      
      // Use stored net earnings and platform fee if they exist
      double platformFee = (widget.hostel['platformFee'] as num?)?.toDouble() ?? -1.0;
      double agentEarnings = (widget.hostel['agentPrice'] as num?)?.toDouble() ?? -1.0;

      // 2. Fallback for legacy listings (re-calculate using global commission)
      if (platformFee < 0 || agentEarnings < 0) {
        final double globalCommissionPercent = await _firestoreService.getGlobalCommission();
        platformFee = (studentPaysTotal * globalCommissionPercent) / 100;
        agentEarnings = studentPaysTotal - platformFee;
      }

      // Create Booking Object
      final bookingData = {
        'hostelId': widget.hostel['id'] ?? 'unknown_id',
        'hostelName': name,
        'location': location,
        'imageUrl': image,
        
        // FINANCIALS RECORD
        'price': studentPaysTotal,     // Full Price
        'agentPrice': agentEarnings,   // Net to Agent
        'platformFee': platformFee,    // Our Cut
        
        'agentId': agentId, 
        
        // Student Info
        'userName': user.displayName ?? 'Student',
        'userId': user.uid,
        'studentSex': selectedSex,
        'roomType': '${widget.hostel['capacity'] ?? '?'} in a room',
        
        'checkIn': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        'checkOut': Timestamp.fromDate(DateTime.now().add(const Duration(days: 120))),
        'status': 'PENDING', 
        'bookingDate': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirestoreService().addBooking(user.uid, bookingData);
      
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
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
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
  
  Future<String?> _getOrCreateChatId() async {
    final user = _auth.currentUser;
    final agentId = widget.hostel['agentId'];
    if (user == null || agentId == null) return null;

    final chatsRef = FirebaseFirestore.instance.collection('chats');
    final query = await chatsRef.where('users', arrayContains: user.uid).get();
    
    String? targetChatId;
    for (var doc in query.docs) {
      final users = List<String>.from(doc['users']);
      if (users.contains(agentId)) {
        targetChatId = doc.id;
        break;
      }
    }

    if (targetChatId == null) {
      final newChat = await chatsRef.add({
        'users': [user.uid, agentId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hostelName': widget.hostel['name'] ?? 'Hostel',
        'studentName': user.displayName ?? 'Student',
        'hostelId': widget.hostel['id'] ?? '',
      });
      targetChatId = newChat.id;
    }
    return targetChatId;
  }

  Future<void> _openChatWithAgent() async {
    final agentId = widget.hostel['agentId'];
    final chatId = await _getOrCreateChatId();

    if (chatId != null && mounted) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
        chatId: chatId, 
        otherUserName: 'Agent', 
        otherUserId: agentId ?? ''
      )));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unable to start chat.")));
    }
  }

  Future<void> _saveContact() async {
    final chatId = await _getOrCreateChatId();
    if (chatId != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agent saved to your Messages list.")));
      Navigator.pop(context);
    }
  }

  void _showContactOptions() {
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
            const Text("Contact Options", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildContactBtn(Icons.call, "Call", Colors.green, () {
                  final phone = widget.hostel['phone'] ?? widget.hostel['contact'] ?? '0550000000'; 
                  launchUrl(Uri.parse("tel:$phone"));
                  Navigator.pop(context);
                }),
                // Removed Save Button per request
                _buildContactBtn(Icons.chat_bubble, "Chat", Colors.blue, () {
                  Navigator.pop(context);
                  _openChatWithAgent();
                }),
                _buildContactBtn(FontAwesomeIcons.whatsapp, "WhatsApp", Colors.teal, () async {
                   final phone = widget.hostel['phone'] ?? widget.hostel['contact'] ?? '0550000000'; 
                   final url = "https://wa.me/$phone?text=Hello, I'm interested in ${widget.hostel['name']}";
                   if (await canLaunchUrl(Uri.parse(url))) {
                     launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                   }
                   Navigator.pop(context);
                }),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildContactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
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
    final image = _getSecureUrl(widget.hostel['image']);
    final hostelId = widget.hostel['id']?.toString();
    final user = _auth.currentUser;

    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 900) {
      return _buildDesktopDetails(context, isDark, textColor, primaryColor, name, location, price, rating, capacity, image, hostelId, user);
    }

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Stack(
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
                      Hero(
                        tag: 'hostel_image_$hostelId',
                        child: CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[300]),
                          errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.error)),
                        ),
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
                                    final bool isManualFull = widget.hostel['isFull'] ?? false;
                                    final confirmedCount = snapshot.data?.docs.length ?? 0;
                                    final totalCapacity = int.tryParse(capacity) ?? 4;
                                    final spotsLeft = totalCapacity - confirmedCount;
                                    final bool isFull = isManualFull || spotsLeft <= 0;
                                    
                                    return Text(
                                      isFull ? "Fully Booked" : "$spotsLeft / $totalCapacity spots left",
                                      style: TextStyle(
                                        color: isFull ? Colors.red : primaryColor,
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
                              return _buildGalleryImage(_getSecureUrl((widget.hostel['gallery'] as List)[index]));
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
                              if (amenity == 'Gym') icon = FontAwesomeIcons.dumbbell;
                              if (amenity == 'Laundry') icon = FontAwesomeIcons.jugDetergent;
                              if (amenity == 'TV Room') icon = FontAwesomeIcons.tv;
                              if (amenity == 'Balcony') icon = FontAwesomeIcons.cloudSun;
                              if (amenity == 'Parking') icon = FontAwesomeIcons.car;
                              if (amenity == 'CCTV') icon = FontAwesomeIcons.video;
                              if (amenity == 'Fridge') icon = FontAwesomeIcons.temperatureLow;
                              
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
                        style: TextStyle(fontSize: 15, color: textColor?.withValues(alpha: 0.8), height: 1.6, letterSpacing: 0.3),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      if (hostelId != null)
                        ReviewsSection(hostelId: hostelId),

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
              padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 30), // Extra bottom padding for safe area
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, -5)),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Total Price", style: TextStyle(color: textColor?.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold)), // Reduced font size slightly
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible( // Use Flexible to allow shrinking
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2).format(double.tryParse(price.toString().replaceAll(',', '')) ?? 0),
                                  style: TextStyle(
                                    fontSize: 22, // Slightly reduced
                                    fontWeight: FontWeight.w900, 
                                    color: primaryColor, 
                                    letterSpacing: -0.5
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collectionGroup('bookings').where('hostelId', isEqualTo: hostelId).where('status', isEqualTo: 'CONFIRMED').snapshots(),
                    builder: (context, snapshot) {
                      final bool isManualFull = widget.hostel['isFull'] ?? false;
                      final confirmedCount = snapshot.data?.docs.length ?? 0;
                      final totalCapacity = int.tryParse(capacity) ?? 4;
                      final isCapacityFull = (totalCapacity - confirmedCount) <= 0;
                      final isFull = isManualFull || isCapacityFull;

                      return ElevatedButton(
                        onPressed: (_isBooking || isFull) ? null : _bookHostel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFull ? Colors.grey : (isDark ? const Color(0xFF333333) : Colors.black),
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: isFull ? 0 : 8,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: _isBooking 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(isFull ? "Fully Booked" : "Book Now", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
          // 4. FLOATING CONTACT ICON
          Positioned(
            bottom: 110, // Just above the booking bar
            right: 20,
            child: FloatingActionButton(
              onPressed: _showContactOptions,
              backgroundColor: primaryColor,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.chat_outlined, color: Colors.white),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDetails(BuildContext context, bool isDark, Color? textColor, Color primaryColor, String name, String location, String price, String rating, String capacity, String image, String? hostelId, User? user) {
     return Scaffold(
       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
       body: Center(
         child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  // LEFT COLUMN (Scrollable Content)
                  Expanded(
                    flex: 10,
                    child: SingleChildScrollView(
                       padding: const EdgeInsets.all(30),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // Back Button & Title
                             Row(
                               children: [
                                 IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
                                 const SizedBox(width: 10),
                                 Expanded(child: Text(name, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor))),
                               ],
                             ),
                             const SizedBox(height: 20),
                             
                             // Main Image
                             ClipRRect(
                               borderRadius: BorderRadius.circular(24),
                               child: CachedNetworkImage(imageUrl: image, height: 500, width: double.infinity, fit: BoxFit.cover),
                             ),
                             const SizedBox(height: 40),
                             
                             Text("Description", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                             const SizedBox(height: 10),
                             Text(
                                "Experience the best student living at $name. We offer spacious rooms, high-speed internet, and a study-friendly environment. Located just 5 minutes from the main campus gate, you'll never be late for lectures.",
                                 style: TextStyle(fontSize: 16, height: 1.6, color: textColor?.withValues(alpha: 0.8)),
                             ),
                             
                             const SizedBox(height: 40),
                             Text("Amenities", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                             const SizedBox(height: 20),
                             Wrap(
                               spacing: 15, 
                               runSpacing: 15, 
                               children: (widget.hostel['amenities'] as List? ?? []).map<Widget>((a) => _buildAmenityChip(context, FontAwesomeIcons.check, a.toString())).toList()
                             ),

                             const SizedBox(height: 40),
                             // Gallery Grid
                             if ((widget.hostel['gallery'] as List?)?.isNotEmpty ?? false) ...[
                               Text("Gallery", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                               const SizedBox(height: 20),
                               GridView.builder(
                                   shrinkWrap: true,
                                   physics: const NeverScrollableScrollPhysics(),
                                   gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2),
                                   itemCount: (widget.hostel['gallery'] as List).length,
                                   itemBuilder: (c, i) => ClipRRect(
                                     borderRadius: BorderRadius.circular(16),
                                     child: CachedNetworkImage(imageUrl: _getSecureUrl((widget.hostel['gallery'] as List)[i]), fit: BoxFit.cover),
                                   ),
                                ),
                             ],
                             
                             const SizedBox(height: 40),
                             if (hostelId != null) ReviewsSection(hostelId: hostelId),
                             const SizedBox(height: 100),
                          ],
                       ),
                    ),
                  ),
                  
                  // RIGHT COLUMN (Sticky Card)
                  Container(
                     width: 420,
                     margin: const EdgeInsets.fromLTRB(0, 30, 30, 30),
                     padding: const EdgeInsets.all(32),
                     decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0,10))],
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                     ),
                     child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(location, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                           const SizedBox(height: 8),
                           Row(
                             crossAxisAlignment: CrossAxisAlignment.baseline,
                             textBaseline: TextBaseline.alphabetic,
                             children: [
                               Text("GHS $price", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primaryColor)),
                             ],
                           ),
                           Text("per semester", style: TextStyle(color: textColor?.withOpacity(0.6))),
                           const SizedBox(height: 24),
                           Divider(color: Colors.grey.withOpacity(0.1)),
                           const SizedBox(height: 24),
                           
                           Row(children: [
                             const Icon(Icons.star, color: Colors.amber, size: 20), 
                             const SizedBox(width: 8),
                             Text("$rating Rating", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                           ]),
                           const SizedBox(height: 12),
                           Row(children: [
                             Icon(Icons.people_outline, color: primaryColor, size: 20),
                             const SizedBox(width: 8),
                             Text("$capacity / room capacity", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: textColor)),
                           ]),
                           
                           const SizedBox(height: 32),
                           SizedBox(
                             width: double.infinity,
                             child: ElevatedButton(
                                onPressed: _bookHostel,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 22),
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 5,
                                ),
                                child: const Text("Book Now", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                             ),
                           ),
                           const SizedBox(height: 16),
                           OutlinedButton.icon(
                              onPressed: _showContactOptions,
                              icon: const Icon(Icons.headset_mic_outlined),
                              label: const Text("Contact Agent"),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                           ),
                        ],
                     ),
                  ),
               ],
            ),
          ),
         ),
       ),
     );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildGalleryImage(String url) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) {
          final gallery = (widget.hostel['gallery'] as List).cast<String>();
          final initialIndex = gallery.indexOf(url);
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                PageView.builder(
                  controller: PageController(initialPage: initialIndex),
                  itemCount: gallery.length,
                  itemBuilder: (context, index) {
                    final imageUrl = gallery[index];
                    return Center(
                      child: Hero(
                        tag: imageUrl,
                        child: InteractiveViewer(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 40, right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                )
              ],
            ),
          );
        }));
      },
      child: Hero(
        tag: url, // Hero animation for gallery
        child: Container(
          margin: const EdgeInsets.only(right: 15),
          width: 140, // Slightly larger
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 5))],
            image: DecorationImage(
              image: CachedNetworkImageProvider(url), 
              fit: BoxFit.cover
            ),
          ),
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
        borderRadius: BorderRadius.circular(16), // Softer corners
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: isDark ? Colors.white : Colors.blue.shade800),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}
