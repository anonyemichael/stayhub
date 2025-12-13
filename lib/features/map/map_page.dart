import 'dart:async';
import 'dart:ui'; // For Glassmorphism
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
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

  @override
  void initState() {
    super.initState();
    _hostelsStream = _firestoreService.getHostels();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (mounted && status.isGranted) {
      setState(() => _locationPermissionGranted = true);
      _moveCameraToUserLocation(); // Move to location once permission is granted
    }
  }

  Future<void> _moveCameraToUserLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
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
      final hostelData = Map<String, dynamic>.from(data);
      hostelData['id'] = doc.id;

      // Simple offset for demo purposes
      final double latOffset = (doc.id.hashCode % 100) * 0.0001;
      final double lngOffset = (doc.id.hashCode % 100) * 0.0001;

      final LatLng position = LatLng(
          _initialCenter.latitude + latOffset,
          _initialCenter.longitude + lngOffset
      );

      return Marker(
        markerId: MarkerId(doc.id),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            (double.tryParse(data['price'].toString().replaceAll(',', '')) ?? 0) > 2000
                ? BitmapDescriptor.hueViolet
                : BitmapDescriptor.hueAzure
        ),
        onTap: () {
          setState(() => _selectedHostel = hostelData);
          if (_mapController != null) {
             _mapController!.animateCamera(
              CameraUpdate.newLatLng(LatLng(position.latitude - 0.002, position.longitude)),
            );
          }
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _hostelsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              // PERFORMANCE OPTIMIZATION: Filter here, not in _createMarkers
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
                onMapCreated: (controller) => _mapController = controller,
                markers: _createMarkers(filteredDocs),
                myLocationEnabled: _locationPermissionGranted,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() => _selectedHostel = null),
              );
            },
          ),

          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _buildGlassSearchBar(context),
                const SizedBox(height: 12),
                _buildFilterList(context),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: _selectedHostel != null ? 240 : 120,
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

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 20,
            right: 20,
            bottom: _selectedHostel != null ? 110 : -250,
            child: _selectedHostel != null
                ? _buildHostelCard(context, _selectedHostel!)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildGlassSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8);
    final textColor = isDark ? Colors.white70 : Colors.grey[600];
    
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
            border: Border.all(color: isDark ? Colors.white12 : Colors.white.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: textColor),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                  decoration: InputDecoration(hintText: "Find hostel near me...", hintStyle: TextStyle(color: textColor), border: InputBorder.none),
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
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filters[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).primaryColor : (Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.6) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))],
              ),
              child: Text(filters[index], style: TextStyle(color: isActive ? Colors.white : null, fontWeight: FontWeight.w600)),
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
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: hostel))),
                      child: const Text("View Details", style: TextStyle(color: Colors.white, fontSize: 12)),
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
