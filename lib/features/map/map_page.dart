import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MapPage extends StatefulWidget {
  final bool isActive;
  const MapPage({super.key, this.isActive = true});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  final LatLng _initialCenter = const LatLng(6.673175, -1.565423);
  bool _locationPermissionGranted = false;

  Map<String, dynamic>? _selectedHostel;
  final ScrollController _chipScrollController = ScrollController();
  
  late Stream<QuerySnapshot> _hostelsStream;
  String _searchQuery = "";
  String _selectedFilter = "Any Price";
  
  bool _showSearchAreaButton = false;
  String? _darkMapStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hostelsStream = _firestoreService.getHostels();
    _checkLocationPermission();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    try {
      _darkMapStyle = await rootBundle.loadString('assets/map_style_dark.json');
    } catch (e) {
      debugPrint("Could not load map style: $e");
    }
  }

  @override
  void didChangePlatformBrightness() {
    _updateMapStyle();
  }

  void _updateMapStyle() {
    if (_mapController == null || _darkMapStyle == null) return;
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (brightness == Brightness.dark) {
      _mapController!.setMapStyle(_darkMapStyle);
    } else {
      _mapController!.setMapStyle(null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    if (kIsWeb) {
      // On web, Geolocator handles permissions or they are managed by browser
      setState(() => _locationPermissionGranted = true);
      if (widget.isActive) {
        _moveCameraToUserLocation();
      }
      return;
    }
    final status = await Permission.location.request();
    if (mounted && status.isGranted) {
      setState(() => _locationPermissionGranted = true);
      if (widget.isActive) {
        _moveCameraToUserLocation();
      }
    }
  }

  Future<void> _moveCameraToUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 16.0),
        ),
      );
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  Set<Marker> _createMarkers(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      finalWtihId(data, doc.id);
      
      LatLng position;
      if (data['latitude'] != null && data['longitude'] != null) {
         position = LatLng(data['latitude'], data['longitude']);
      } else {
         // Fallback for old data without coordinates
         final double latOffset = (doc.id.hashCode % 100) * 0.0001;
         final double lngOffset = (doc.id.hashCode % 100) * 0.0001;
         position = LatLng(
             _initialCenter.latitude + latOffset,
             _initialCenter.longitude + lngOffset
         );
      }

      return Marker(
        markerId: MarkerId(doc.id),
        position: position,
        // Differentiate expensive/cheap hostels with color hue
        icon: BitmapDescriptor.defaultMarkerWithHue(
            (double.tryParse(data['price'].toString().replaceAll(',', '')) ?? 0) > 2000
                ? BitmapDescriptor.hueViolet
                : BitmapDescriptor.hueAzure
        ),
        onTap: () {
          setState(() => _selectedHostel = data);
          if (_mapController != null) {
             _mapController!.animateCamera(
              CameraUpdate.newLatLng(LatLng(position.latitude - 0.002, position.longitude)),
            );
          }
        },
      );
    }).toSet();
  }
  
  void finalWtihId(Map<String, dynamic> data, String id) {
    data['id'] = id;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink(); 

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _hostelsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final filteredDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final location = (data['location'] ?? '').toString().toLowerCase();
                final amenities = List.from(data['amenities'] ?? []);

                if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !location.contains(_searchQuery)) {
                  return false;
                }

                switch (_selectedFilter) {
                  case "WiFi": return amenities.contains("WiFi");
                  case "AC": return amenities.contains("AC");
                  case "Security": return amenities.contains("Security");
                  case "Close to Campus": return location.contains("campus") || location.contains("knust");
                  default: return true;
                }
              }).toList();

              return GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialCenter, zoom: 14),
                onMapCreated: (controller) {
                   _mapController = controller;
                   _updateMapStyle();
                },
                onCameraMove: (_) {
                   if (!_showSearchAreaButton) setState(() => _showSearchAreaButton = true);
                },
                markers: _createMarkers(filteredDocs),
                myLocationEnabled: _locationPermissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() => _selectedHostel = null),
              );
            },
          ),

          // Top Search Bar
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: PointerInterceptor(
              child: Column(
                children: [
                  _buildGlassSearchBar(context),
                  const SizedBox(height: 12),
                  _buildFilterList(context),
                ],
              ),
            ),
          ),
          
          // "Search this area" Button
          if (_showSearchAreaButton)
            Positioned(
              top: 160,
              left: 100,
              right: 100,
              child: PointerInterceptor(
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                       setState(() => _showSearchAreaButton = false);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Searching this area..."), duration: Duration(milliseconds: 500)));
                       // In a real app, you'd trigger a geo-query here based on map bounds
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))]
                      ),
                      child: const Text("Search this area", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ),
              ),
            ),

          // Map Controls
          Positioned(
            right: 16,
            bottom: _selectedHostel != null ? 240 : 120,
            child: PointerInterceptor(
              child: Column(
                children: [
                  _buildMapButton(context, Icons.add, () => _mapController?.animateCamera(CameraUpdate.zoomIn())),
                  const SizedBox(height: 10),
                  _buildMapButton(context, Icons.remove, () => _mapController?.animateCamera(CameraUpdate.zoomOut())),
                  if (_locationPermissionGranted) ...[
                    const SizedBox(height: 20),
                    _buildMapButton(context, Icons.near_me_rounded, _moveCameraToUserLocation, isPrimary: true),
                  ]
                ],
              ),
            ),
          ),

          // Hostel Card Slide-up
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 20,
            right: 20,
            bottom: _selectedHostel != null ? 110 : -250,
            child: PointerInterceptor(
              child: _selectedHostel != null
                  ? _buildHostelCard(context, _selectedHostel!)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildGlassSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.9); // Increased opacity for light mode
    final textColor = isDark ? Colors.white70 : Colors.black87; // Darker text for light mode
    final hintColor = isDark ? Colors.white38 : Colors.black54; 
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 55,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)), // Subtle border in light mode
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: hintColor),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(hintText: "Find hostel near me...", hintStyle: TextStyle(color: hintColor), border: InputBorder.none),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear, size: 20, color: textColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterList(BuildContext context) {
    final filters = ["Any Price", "WiFi", "AC", "Close to Campus", "Security"];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final isActive = _selectedFilter == filters[index];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filters[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).primaryColor : (isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
              ),
              child: Text(
                filters[index], 
                style: TextStyle(
                  color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87), // Dark text in light mode
                  fontWeight: FontWeight.w600
                )
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHostelCard(BuildContext context, Map<String, dynamic> hostel) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: hostel))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(image: NetworkImage(hostel['image'] ?? 'https://picsum.photos/200'), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(hostel['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)
                      ),
                      Row(children: [const Icon(Icons.star, color: Colors.amber, size: 16), Text(" ${hostel['rating'] ?? '4.5'}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("GHS ${hostel['price'] ?? '0'} / sem", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: hostel))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("View Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(BuildContext context, IconData icon, VoidCallback onPressed, {bool isPrimary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isPrimary ? Theme.of(context).primaryColor : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final iconColor = isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
