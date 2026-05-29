import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:stayhub/services/app_config_service.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:stayhub/services/local_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPage extends StatefulWidget {
  final bool isActive;
  const MapPage({super.key, this.isActive = true});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String? _darkMapStyle;
  String? _lightMapStyle;
  GoogleMapController? _mapController;

  LatLng _initialCenter = const LatLng(6.673175, -1.565423); // Default to KNUST (Ghana)
  bool _isFirstLoad = true;
  bool _locationPermissionGranted = false;
  List<QueryDocumentSnapshot> _searchResults = [];
  bool _showSuggestions = false;
  String? _userSchool;

  // School Coordinates (Ghana)
  static final Map<String, LatLng> _schoolCoordinates = {
    'UENR': const LatLng(7.3456, -2.3451), // Sunyani
    'CUG': const LatLng(7.3300, -2.3280),   // Fiapre, Sunyani (Catholic University College)
    'KNUST': const LatLng(6.6745, -1.5716), // Kumasi
    'UDS': const LatLng(9.4034, -0.8424),   // Tamale
    'UCC': const LatLng(5.1036, -1.2825),   // Cape Coast
    'LEGON': const LatLng(5.6508, -0.1870), // UG Legon
    'UPSA': const LatLng(5.6322, -0.1848),  // UPSA
    'ATU': const LatLng(5.5539, -0.2017),   // Accra Technical University
    'GIJ': const LatLng(5.5587, -0.1915),   // GIJ
    'CASS': const LatLng(6.6732, -1.5670),  // CASS
    'UENR': const LatLng(7.3400, -2.3276),  // Sunyani
  };

  Map<String, dynamic>? _selectedHostel;
  final ScrollController _chipScrollController = ScrollController();
  
  late Stream<QuerySnapshot> _hostelsStream;
  String _searchQuery = "";
  String _selectedFilter = "Any Price";
  
  bool _showSearchAreaButton = false;
  Set<Marker> _markers = {};
  List<QueryDocumentSnapshot> _lastDocs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hostelsStream = _firestoreService.getHostels();
    
    // We try to load cached data FIRST to set _initialCenter before build()
    _loadInitialLocationSync(); 
    
    _loadCachedMapData();
    _fetchUserSchool(); // Fetch current user's school for smart centering
    _checkLocationPermission();
    _loadMapStyle();
  }

  void _loadInitialLocationSync() {
     // Check if we have a school saved in SharedPreferences or similar
     // This is a synchronous-looking check but usually we use a Future
     // For now, let's make _loadCachedMapData more aggressive
  }

  Future<void> _loadCachedMapData() async {
    // 1. Load User School from cache
    final cachedProfile = await LocalCacheService.load(LocalCacheService.KEY_USER_PROFILE);
    if (cachedProfile != null && mounted) {
      final String? school = cachedProfile['school'];
      setState(() {
        _userSchool = school;
      });
      if (school != null && _schoolCoordinates.containsKey(school)) {
        setState(() {
          _initialCenter = _schoolCoordinates[school]!;
        });
        // If map is already created, move it
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_initialCenter, 14));
      }
    }

    // 2. Load dynamic coordinates from cache
    final cachedCoords = await LocalCacheService.load('cached_school_coords');
    if (cachedCoords != null && mounted) {
      setState(() {
        (cachedCoords as Map<String, dynamic>).forEach((key, value) {
          if (value is Map && value['lat'] != null && value['lng'] != null) {
            _schoolCoordinates[key] = LatLng(
              (value['lat'] as num).toDouble(),
              (value['lng'] as num).toDouble()
            );
          }
        });
      });
      
      // Re-center if school found in cached coordinates
      if (_userSchool != null && _schoolCoordinates.containsKey(_userSchool!)) {
        _initialCenter = _schoolCoordinates[_userSchool!]!;
      }
    }
  }

  Future<void> _fetchUserSchool() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          final String? school = doc.data()?['school'];
          debugPrint("MapPage: Fetched user school from Firestore: $school");
          setState(() {
            _userSchool = school;
          });
        }
        
        // Fetch dynamic coordinates
        final config = await AppConfigService().getConfig();
        final Map<String, dynamic> dynCoords = config['school_coordinates'] as Map<String, dynamic>? ?? {};
        if (dynCoords.isNotEmpty && mounted) {
           setState(() {
              dynCoords.forEach((key, value) {
                if (value is Map && value['lat'] != null && value['lng'] != null) {
                  _schoolCoordinates[key] = LatLng(
                    (value['lat'] as num).toDouble(), 
                    (value['lng'] as num).toDouble()
                  );
                }
              });
           });
           // Save to cache
           await LocalCacheService.save('cached_school_coords', dynCoords);
        }

        if (_userSchool != null && _schoolCoordinates.containsKey(_userSchool!)) {
           _initialCenter = _schoolCoordinates[_userSchool!]!;
           debugPrint("MapPage: Setting initial center to student school: $_userSchool at $_initialCenter");
           if (_mapController != null) {
              _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_initialCenter, 14));
           }
        } else {
           debugPrint("MapPage: No specific school fallback found for '$_userSchool'.");
        }

        if (_locationPermissionGranted) {
           _moveCameraToUserLocation();
        }
      } catch (e) {
        debugPrint("Error fetching user school or coordinates: $e");
      }
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      _darkMapStyle = await rootBundle.loadString('assets/map_style_dark.json');
      _lightMapStyle = await rootBundle.loadString('assets/map_style_light.json');
      debugPrint("MapPage: Map styles loaded successfully.");
      _updateMapStyle(); // Apply styles immediately after loading
    } catch (e) {
      debugPrint("MapPage Error: Could not load map styles: $e");
    }
  }

  @override
  void didChangePlatformBrightness() {
    _updateMapStyle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMapStyle();
  }

  void _updateMapStyle() {
    if (_mapController == null || !mounted) return;
    final brightness = Theme.of(context).brightness;
    debugPrint("MapPage: Updating map style for $brightness (App Theme)");
    
    if (brightness == Brightness.dark && _darkMapStyle != null) {
      debugPrint("MapPage: Applying Dark Style");
      _mapController!.setMapStyle(_darkMapStyle);
    } else if (brightness == Brightness.light && _lightMapStyle != null) {
      debugPrint("MapPage: Applying Light Style");
      _mapController!.setMapStyle(_lightMapStyle);
    } else {
      debugPrint("MapPage: Applying Default Style (Style is null)");
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

  void _applyFilters() {
    final filteredDocs = _lastDocs.where((doc) {
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

    debugPrint("MapPage: Found ${filteredDocs.length} hostels matching filters.");

    if (mounted) {
      setState(() {
        _markers = _createMarkers(filteredDocs);
        _searchResults = filteredDocs;
      });
    }
  }

  Future<void> _moveCameraToUserLocation() async {
    try {
      // Use a timeout to prevent hanging if GPS is slow
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (!mounted) return;
      
      LatLng target = LatLng(position.latitude, position.longitude);
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );
    } catch (e) {
      debugPrint("Location Error or Timeout: $e");
      // Fallback: If GPS fails/times out, center on school
      if (_userSchool != null && _schoolCoordinates.containsKey(_userSchool!)) {
        debugPrint("MapPage: Falling back to student school: $_userSchool");
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_schoolCoordinates[_userSchool!]!, 14),
        );
      } else {
        debugPrint("MapPage: No school fallback found, staying at KNUST.");
      }
    }
  }

  void _updateMarkersFromSnapshot(QuerySnapshot snapshot) {
    // Only update if document list has changed (simple length check for speed)
    if (_lastDocs.length != snapshot.docs.length) {
       _lastDocs = snapshot.docs;
       _applyFilters();
    }
  }

  Set<Marker> _createMarkers(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return {};
    
    return docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      data['id'] = doc.id;
      
      double? lat;
      double? lng;

      // Robust coordinate parsing
      if (data['latitude'] != null && data['longitude'] != null) {
        lat = double.tryParse(data['latitude'].toString());
        lng = double.tryParse(data['longitude'].toString());
      }

      final LatLng position;
      if (lat != null && lng != null) {
         position = LatLng(lat, lng);
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
  
  void _fitBounds(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty || _mapController == null) return;
    
    double? minLat, maxLat, minLng, maxLng;
    
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = double.tryParse(data['latitude']?.toString() ?? "");
      final lng = double.tryParse(data['longitude']?.toString() ?? "");
      
      if (lat != null && lng != null) {
        if (minLat == null || lat < minLat) minLat = lat;
        if (maxLat == null || lat > maxLat) maxLat = lat;
        if (minLng == null || lng < minLng) minLng = lng;
        if (maxLng == null || lng > maxLng) maxLng = lng;
      }
    }
    
    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50,
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    debugPrint("MapPage: Controller created, applying initial style.");
    _updateMapStyle();
    
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    // Removed the !widget.isActive check to allow IndexedStack to keep the map state alive
    // and initialize it even when the tab isn't currently visible.

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _initialCenter, zoom: 14),
              onMapCreated: (controller) {
                _mapController = controller;
                debugPrint("MapPage: Controller created, applying initial style.");
                _updateMapStyle();
                _applyFilters();
              },
              onCameraMove: (_) {
                if (!_showSearchAreaButton) setState(() => _showSearchAreaButton = true);
              },
              markers: _markers,
              myLocationEnabled: _locationPermissionGranted,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onTap: (_) => setState(() => _selectedHostel = null),
            ),
          ),
          
          // Hidden StreamBuilder to update markers in background
          StreamBuilder<QuerySnapshot>(
            stream: _hostelsStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateMarkersFromSnapshot(snapshot.data!);
                });
              }
              return const SizedBox.shrink();
            },
          ),

          // Top Search Bar
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: RepaintBoundary(
              child: PointerInterceptor(
                child: Column(
                  children: [
                    _buildGlassSearchBar(context),
                    if (_showSuggestions && _searchResults.isNotEmpty && _searchQuery.isNotEmpty)
                       _buildSuggestionsPopup(context),
                    const SizedBox(height: 12),
                    _buildFilterList(context),
                  ],
                ),
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
            child: RepaintBoundary(
              child: PointerInterceptor(
                child: _selectedHostel != null
                    ? _buildHostelCard(context, _selectedHostel!)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildGlassSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9); // Increased opacity for light mode
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
            border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)), // Subtle border in light mode
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: hintColor),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                       _searchQuery = value.toLowerCase().trim();
                       _showSuggestions = true;
                    });
                    _applyFilters();
                  },
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(hintText: "Find hostel near me...", hintStyle: TextStyle(color: hintColor), border: InputBorder.none),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear, size: 20, color: textColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                      _showSuggestions = false;
                    });
                    _applyFilters();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsPopup(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length.clamp(0, 5),
          separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
          itemBuilder: (context, index) {
            final doc = _searchResults[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? "Hostel";
            
            return ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined, size: 18),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(data['location'] ?? "Nearby", style: const TextStyle(fontSize: 12)),
              onTap: () {
                final lat = double.tryParse(data['latitude']?.toString() ?? "");
                final lng = double.tryParse(data['longitude']?.toString() ?? "");
                
                setState(() {
                  _searchController.text = name;
                  _searchQuery = name.toLowerCase();
                  _showSuggestions = false;
                  _selectedHostel = data;
                  _selectedHostel!['id'] = doc.id;
                });
                
                if (lat != null && lng != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(LatLng(lat - 0.002, lng), 15),
                  );
                }
              },
            );
          },
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
            onTap: () {
              setState(() => _selectedFilter = filters[index]);
              _applyFilters();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).primaryColor : (isDark ? Colors.black.withOpacity(0.6) : Colors.white),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hostel['name'] ?? 'No Name',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${hostel['price'] ?? '0'} GHS/yr",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          Text(
                            " ${hostel['rating'] ?? '4.5'}", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          final latStr = hostel['latitude']?.toString() ?? '';
                          final lngStr = hostel['longitude']?.toString() ?? '';
                          final name = hostel['name']?.toString() ?? 'Hostel';
                          final location = hostel['location']?.toString() ?? '';

                          debugPrint("MapPage: Button pressed for $name at $latStr, $lngStr");

                          if (latStr.isNotEmpty && lngStr.isNotEmpty) {
                            final lat = double.tryParse(latStr);
                            final lng = double.tryParse(lngStr);
                            if (lat != null && lng != null) {
                              _launchDirections(lat, lng);
                              return;
                            }
                          }
                          
                          // Fallback to text search if coordinates are missing or invalid
                          _launchDirectionsByName(name, location);
                        },
                        icon: const Icon(Icons.directions, size: 16),
                        label: const Text("Directions", style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
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
    );
  }

  Future<void> _launchDirections(double lat, double lng) async {
    final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final httpsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking');
    
    debugPrint("MapPage: Launching directions to $lat, $lng");
    
    try {
      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(httpsUrl)) {
        await launchUrl(httpsUrl, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("MapPage: No map application found.");
      }
    } catch (e) {
      debugPrint("MapPage Error: Could not launch directions: $e");
    }
  }

  Future<void> _launchDirectionsByName(String name, String location) async {
    final query = Uri.encodeComponent("$name $location");
    final url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$query");
    
    debugPrint("MapPage: Launching directions by name: $name");
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("MapPage Error: Could not launch directions by name: $e");
    }
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

