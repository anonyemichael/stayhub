import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  LatLng _pickedLocation = const LatLng(6.673175, -1.565423); // Default KNUST
  GoogleMapController? _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    final location = Location();
    try {
      final hasPermission = await location.requestPermission();
      if (hasPermission == PermissionStatus.granted) {
        final locData = await location.getLocation();
        if (locData.latitude != null && locData.longitude != null) {
          setState(() {
            _pickedLocation = LatLng(locData.latitude!, locData.longitude!);
            _isLoading = false;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(_pickedLocation));
        }
      }
    } catch (_) {
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Hostel Location"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _pickedLocation);
            }, 
            child: const Text("SAVE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _pickedLocation, zoom: 16),
            onMapCreated: (c) => _mapController = c,
            onCameraMove: (pos) => _pickedLocation = pos.target,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          const Center(
            child: Icon(Icons.location_pin, size: 50, color: Colors.blueAccent),
          ),
          Positioned(
             bottom: 40,
             left: 40, 
             right: 40,
             child: Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)]),
               child: const Text("Pan the map to place the pin at the hostel's entrance.", textAlign: TextAlign.center),
             ),
          )
        ],
      ),
    );
  }
}
