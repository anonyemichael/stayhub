import 'dart:async';
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
import 'package:stayhub/core/image_utils.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:stayhub/services/payment_sheet.dart';

class HostelDetailsPage extends StatefulWidget {
  final Map<String, dynamic> hostel;
  final String? preSelectedRoomId;

  const HostelDetailsPage({super.key, required this.hostel, this.preSelectedRoomId});

  @override
  State<HostelDetailsPage> createState() => _HostelDetailsPageState();
}

class _HostelDetailsPageState extends State<HostelDetailsPage> {
  bool _isBooking = false;
  int _confirmedBookingsCount = 0;
  int _totalReviewCount = 0;
  double _averageRating = 0.0;
  bool _isAvailabilityLoading = true;
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();
  final _paymentService = PaymentService();
  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _hostelSubscription;
  
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _selectedRoom;
  Map<String, dynamic>? _pendingBooking;

  @override
  void initState() {
    super.initState();
    _initializeRooms();
    _listenToHostel();
    _listenToAvailability();
    _listenToReviews();
    _checkPendingBooking();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _hostelSubscription?.cancel();
    super.dispose();
  }

  void _listenToHostel() {
    final hostelId = widget.hostel['id'];
    if (hostelId == null) return;

    _hostelSubscription = FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            final rawRooms = data['rooms'] as List?;
            if (rawRooms != null) {
              _rooms = List<Map<String, dynamic>>.from(rawRooms);
              
              // Update selected room details if it exists in the new list
              if (_selectedRoom != null) {
                final found = _rooms.where((r) => r['type'] == _selectedRoom!['type']).toList();
                if (found.isNotEmpty) {
                  _selectedRoom = found.first;
                }
              }
            }
          });
        }
      }
    });
  }

  void _listenToAvailability() {
    _bookingsSubscription = FirebaseFirestore.instance
        .collection('hostelRoomStates')
        .where('hostelId', isEqualTo: widget.hostel['id'])
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        int totalOccupied = 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final reservations = data['reservations'] as List? ?? [];
          
          totalOccupied += reservations.where((r) {
            final status = r['status'];
            // Count confirmed/paid bookings and active pending locks
            if (status == 'PAID' || status == 'CONFIRMED' || status == 'CHECKED_IN') return true;
            final expiresAtStr = r['expiresAt']?.toString() ?? '';
            final expiresAt = DateTime.tryParse(expiresAtStr)?.millisecondsSinceEpoch ?? 0;
            return expiresAt > now;
          }).length;
        }

        setState(() {
          _confirmedBookingsCount = totalOccupied;
          _isAvailabilityLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint('[StayHub] Availability listener error (Safe Fallback): $error');
      if (mounted) {
        setState(() {
          _isAvailabilityLoading = false;
          // Note: _confirmedBookingsCount stays 0, assuming hostel is not full if we can't check
        });
      }
    });
  }

  int _getTotalCapacityInSlots() {
    int total = 0;
    if (_rooms.isEmpty) {
       // Fallback to legacy capacity
       return (widget.hostel['capacity'] is int) 
          ? widget.hostel['capacity'] 
          : (int.tryParse(widget.hostel['capacity']?.toString() ?? '4') ?? 4);
    }
    for (var r in _rooms) {
      int q = (r['quantity'] as num? ?? 1).toInt();
      int c = (r['capacity'] as num? ?? 4).toInt();
      total += (q * c);
    }
    return total;
  }

  void _listenToReviews() {
    final hostelId = widget.hostel['id'];
    if (hostelId == null) return;

    FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .collection('reviews')
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.docs.isNotEmpty) {
        double total = 0;
        for (var doc in snapshot.docs) {
          total += (doc.data()['rating'] as num?)?.toDouble() ?? 0;
        }
        setState(() {
          _totalReviewCount = snapshot.docs.length;
          _averageRating = total / snapshot.docs.length;
        });
      }
    });
  }

  void _checkPendingBooking() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final hostelId = widget.hostel['id'];
    if (hostelId == null) return;

    // We check for any pending booking for this user and hostel
    // to prevent duplicate lock attempts and allow resumption.
    FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('hostelId', isEqualTo: hostelId)
        .where('status', isEqualTo: 'PAYMENT_PENDING')
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (mounted && snap.docs.isNotEmpty) {
        setState(() {
          _pendingBooking = snap.docs.first.data();
          // Auto-select the room if resuming
          final roomId = _pendingBooking!['roomId'];
          final found = _rooms.where((r) => r['id'] == roomId).toList();
          if (found.isNotEmpty) {
            _selectedRoom = found.first;
          }
        });
      } else if (mounted) {
        setState(() => _pendingBooking = null);
      }
    });
  }

  void _initializeRooms() {
    final rawRooms = widget.hostel['rooms'] as List?;
    if (rawRooms != null && rawRooms.isNotEmpty) {
      _rooms = List<Map<String, dynamic>>.from(rawRooms);
      
      if (widget.preSelectedRoomId != null) {
        final found = _rooms.where((r) => r['id']?.toString() == widget.preSelectedRoomId).toList();
        if (found.isNotEmpty) {
           _selectedRoom = found.first;
        } else {
           _selectedRoom = _rooms.first;
        }
      } else {
        _selectedRoom = _rooms.first;
      }
    } else {
      // Legacy fallback
      final int cap = (widget.hostel['capacity'] is int) 
          ? widget.hostel['capacity'] 
          : (int.tryParse(widget.hostel['capacity']?.toString() ?? '4') ?? 4);
          
      _rooms = [{
        'id': 'legacy',
        'name': 'Standard Room',
        'type': 'Standard',
        'capacity': cap,
        'quantity': 1,
        'available': cap,
        'price': (widget.hostel['price'] as num?)?.toDouble() ?? 0.0,
      }];
      _selectedRoom = _rooms.first;
    }
  }

  double _getCommission(double roomPrice) {
    // 10% of the room price
    return roomPrice * 0.10; 
  }

  String _getPriceDisplay() {
    if (_rooms.isEmpty) return "GHS 0.00";
    
    final prices = _rooms.map((r) {
      final base = (r['price'] as num?)?.toDouble() ?? 0.0;
      return base + _getCommission(base);
    }).toList();
    
    prices.sort();
    
    if (prices.length > 1 && prices.first != prices.last) {
      return "GHS ${prices.first.toStringAsFixed(0)} - ${prices.last.toStringAsFixed(0)}";
    }
    return "GHS ${prices.first.toStringAsFixed(0)}";
  }

  int _getTotalSlotsLeft() {
    int total = 0;
    for (var r in _rooms) {
      total += (r['available'] as num? ?? 0).toInt();
    }
    return total;
  }

  int _getTotalCapacity() {
    int total = 0;
    for (var r in _rooms) {
      total += (r['quantity'] as num? ?? 0).toInt();
    }
    return total;
  }
  
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

    // ─── RESUME FLOW ─────────────────────────────────────────────────────────
    if (_pendingBooking != null) {
      final authUrl = _pendingBooking!['authorizationUrl'];
      final accessCode = _pendingBooking!['accessCode'] ?? '';
      final reference = _pendingBooking!['paymentReference'];
      final bookingId = _pendingBooking!['bookingId'];

      if (authUrl != null && reference != null) {
        final success = await PaymentSheet.show(
          context,
          authUrl: authUrl,
          accessCode: accessCode,
          reference: reference,
          bookingId: bookingId,
          amount: (_pendingBooking!['amounts']?['total'] as num?)?.toDouble() ?? 0.0,
        );
        if (success == true) {
          // Success is handled by Firestore listener in PaymentSheet or here if needed
        }
        return;
      }
    }

    // ─── NEW BOOKING FLOW ────────────────────────────────────────────────────
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a specific room type above to continue.")));
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
      final checkIn = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      final checkOut = DateTime.now().add(const Duration(days: 120)).toIso8601String();

      final success = await _paymentService.startSecureBooking(
        context: context,
        hostelId: widget.hostel['id'] ?? '',
        roomId: _selectedRoom!['id']?.toString() ?? 'legacy',
        checkIn: checkIn,
        checkOut: checkOut,
        studentSex: selectedSex,
      );

      if (success && mounted) {
        // Success handled by PaymentSheet/Redirect
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
    final latStr = widget.hostel['latitude']?.toString() ?? '';
    final lngStr = widget.hostel['longitude']?.toString() ?? '';
    final name = widget.hostel['name']?.toString() ?? 'Hostel';
    final location = widget.hostel['location']?.toString() ?? '';

    Uri url;
    Uri? geoUrl;

    if (latStr.isNotEmpty && lngStr.isNotEmpty) {
      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lngStr);
      if (lat != null && lng != null) {
        geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
        url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
      } else {
        final query = Uri.encodeComponent("$name $location");
        url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$query");
      }
    } else {
      final query = Uri.encodeComponent("$name $location");
      url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$query");
    }

    try {
      if (geoUrl != null && await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
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
      // Fetch agent name for searchability
      String agentName = 'Agent';
      final agentDoc = await FirebaseFirestore.instance.collection('users').doc(agentId).get();
      if (agentDoc.exists) {
        agentName = (agentDoc.data() as Map<String, dynamic>)['name'] ?? 'Agent';
      }

      final newChat = await chatsRef.add({
        'users': [user.uid, agentId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hostelName': widget.hostel['name'] ?? 'Hostel',
        'studentName': user.displayName ?? 'Student',
        'agentName': agentName,
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
                    color: cardColor.withOpacity(0.9),
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
                      color: cardColor.withOpacity(0.9),
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
                          imageUrl: ImageUtils.getSecureUrl(image),
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
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                    const SizedBox(width: 4),
                                    Text(_averageRating > 0 ? _averageRating.toStringAsFixed(1) : rating, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text("$_totalReviewCount reviews", style: TextStyle(color: textColor?.withOpacity(0.6), fontSize: 12)),
                              const SizedBox(height: 4),
                              if (hostelId != null)
                                Text(
                                  ((widget.hostel['isFull'] ?? false) || _getTotalSlotsLeft() <= 0) 
                                      ? "Fully Booked" 
                                      : "${_getTotalSlotsLeft()} spots left",
                                  style: TextStyle(
                                    color: ((widget.hostel['isFull'] ?? false) || _getTotalSlotsLeft() <= 0) ? Colors.red : primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12
                                  ),
                                )
                              else
                                Text("$capacity / room", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue, size: 18),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(location, 
                              style: TextStyle(fontSize: 16, color: textColor?.withOpacity(0.7)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Prominent Directions Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text("Get Directions to Hostel", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
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
                              return _buildGalleryImage(ImageUtils.getSecureUrl((widget.hostel['gallery'] as List)[index]));
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

                      // Room Selection
                      Text("Available Rooms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _rooms.length,
                          itemBuilder: (context, index) {
                            final room = _rooms[index];
                            final isSelected = _selectedRoom == room;
                            final int available = (room['available'] as num? ?? 0).toInt();
                            final bool isRoomFull = available <= 0;

                            return GestureDetector(
                              onTap: isRoomFull ? null : () => setState(() => _selectedRoom = room),
                              child: Container(
                                width: 180,
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? (isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05))
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected 
                                        ? const Color(0xFF2563EB) 
                                        : (isDark ? Colors.white10 : Colors.grey[200]!),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(room['type'] ?? room['name'] ?? '${room['capacity'] ?? '?'} in a room', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), maxLines: 1)),
                                        if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 16),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      isRoomFull ? "SOLD OUT" : "$available Slots left",
                                      style: TextStyle(
                                        color: isRoomFull ? Colors.red : (isDark ? Colors.white70 : Colors.grey[600]),
                                        fontSize: 10, fontWeight: FontWeight.w700
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "GHS ${((room['price'] as num? ?? 0).toDouble() + _getCommission((room['price'] as num? ?? 0).toDouble())).toStringAsFixed(0)}",
                                      style: TextStyle(
                                        color: isRoomFull ? Colors.grey : const Color(0xFF2563EB),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Room Gallery (if available for selected room)
                      if (_selectedRoom != null && (_selectedRoom!['gallery'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 20),
                        Text("Room Photos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (_selectedRoom!['gallery'] as List).where((i) => i != null).length,
                            itemBuilder: (context, index) {
                              final images = (_selectedRoom!['gallery'] as List).where((i) => i != null).map((e) => _getSecureUrl(e.toString())).toList();
                              return _buildGalleryImage(images[index], fullGallery: images);
                            },
                          ),
                        ),
                      ] else if (_selectedRoom != null && _selectedRoom!['image'] != null) ...[
                        const SizedBox(height: 20),
                        Text("Room Photo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 10),
                        _buildGalleryImage(_getSecureUrl(_selectedRoom!['image']), width: double.infinity, height: 180, fullGallery: [_getSecureUrl(_selectedRoom!['image'])]),
                      ],

                      const SizedBox(height: 30),

                      // Room-Specific Amenities
                      if (_selectedRoom != null && (_selectedRoom!['amenities'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 24),
                        Text("Room Amenities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: (_selectedRoom!['amenities'] as List).map((a) => _buildMiniRoomAmenity(a.toString(), isDark)).toList(),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Gallery Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedRoom != null ? "Room Photos" : "Property Photos", 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                          ),
                          if (_selectedRoom != null)
                             Text("${(_selectedRoom!['images'] as List? ?? [(_selectedRoom!['image'])]).where((i) => i != null).length} photos", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _selectedRoom != null 
                              ? (_selectedRoom!['images'] as List? ?? [(_selectedRoom!['image'])]).where((i) => i != null).length
                              : (widget.hostel['gallery'] as List? ?? []).where((i) => i != null).length,
                          itemBuilder: (context, index) {
                            final List<String> gallery = _selectedRoom != null 
                                ? (_selectedRoom!['images'] as List? ?? [(_selectedRoom!['image'])]).where((i) => i != null).map((e) => _getSecureUrl(e.toString())).toList()
                                : (widget.hostel['gallery'] as List? ?? []).where((i) => i != null).map((e) => _getSecureUrl(e.toString())).toList();
                            
                            final imageUrl = gallery[index];
                            return _buildGalleryImage(imageUrl, width: 220, height: 160, fullGallery: gallery);
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Property Description
                      Text("About Property", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 10),
                      Text(
                        widget.hostel['description'] ?? "Experience the best student living at $name. We offer spacious rooms, high-speed internet, and a study-friendly environment.",
                        style: TextStyle(fontSize: 15, color: textColor?.withOpacity(0.8), height: 1.6, letterSpacing: 0.3),
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
              padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 30), // Extra bottom padding for safe area
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, -5)),
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
                        Text("Total Price", style: TextStyle(color: textColor?.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)), // Reduced font size slightly
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _selectedRoom != null 
                                    ? "GHS ${((_selectedRoom!['price'] as num? ?? 0).toDouble() + _getCommission((_selectedRoom!['price'] as num? ?? 0).toDouble())).toStringAsFixed(2)}"
                                    : _getPriceDisplay(),
                                  style: TextStyle(
                                    fontSize: 22, 
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
                    Builder(
                      builder: (context) {
                        final bool isManualFull = widget.hostel['isFull'] ?? false;
                        
                        // Check if specific selected room is full based on DB status
                        final bool isSelectedRoomFull = _selectedRoom != null && (_selectedRoom!['available'] as num? ?? 0) <= 0;
                        
                        // Live check: compare total hostel slots with total confirmed bookings
                        final totalHostelSlots = _getTotalCapacityInSlots();
                        final isHostelCapacityFull = (totalHostelSlots - _confirmedBookingsCount) <= 0;
                        
                        final isFull = isManualFull || isSelectedRoomFull || isHostelCapacityFull;

                        return ElevatedButton(
                          onPressed: (_isBooking || isFull || _isAvailabilityLoading) ? null : _bookHostel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFull ? Colors.grey : (isDark ? const Color(0xFF333333) : Colors.black),
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: isFull ? 0 : 8,
                            shadowColor: Colors.black.withOpacity(0.3),
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
                                 style: TextStyle(fontSize: 16, height: 1.6, color: textColor?.withOpacity(0.8)),
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
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0,10))],
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
                                Text(
                                  "GHS ${NumberFormat.decimalPattern().format((double.tryParse(price.replaceAll(',', '')) ?? 0) * 1.10)}", 
                                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primaryColor)
                                ),
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
                                   backgroundColor: _pendingBooking != null ? Colors.orange[700] : primaryColor,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                   elevation: 5,
                                 ),
                                 child: Text(
                                   _pendingBooking != null ? "Resume Payment" : "Book Now", 
                                   style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                                 ),
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

  Widget _buildGalleryImage(String url, {double width = 100, double height = 100, List<String>? fullGallery}) {
    return GestureDetector(
      onTap: () {
        final gallery = fullGallery ?? (widget.hostel['gallery'] as List?)?.map((e) => _getSecureUrl(e.toString())).toList() ?? [url];
        final initialIndex = gallery.contains(url) ? gallery.indexOf(url) : 0;
        
        Navigator.push(context, MaterialPageRoute(builder: (_) {
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
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        }));
      },
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Hero(
            tag: url,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.error)),
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
  Widget _buildMiniRoomAmenity(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getAmenityIcon(label), size: 14, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  IconData _getAmenityIcon(String name) {
    switch (name.toLowerCase()) {
      case 'ac': return Icons.ac_unit_rounded;
      case 'fan': return Icons.mode_fan_off_rounded;
      case 'wifi': return Icons.wifi_rounded;
      case 'fridge': return Icons.kitchen_rounded;
      case 'study table': return Icons.desk_rounded;
      case 'wardrobe': return Icons.door_sliding_rounded;
      case 'balcony': return Icons.balcony_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }
}

