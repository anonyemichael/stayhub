import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/features/agent/location_picker_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddHostelPage extends StatefulWidget {
  const AddHostelPage({super.key});

  @override
  State<AddHostelPage> createState() => _AddHostelPageState();
}

class _AddHostelPageState extends State<AddHostelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descController = TextEditingController();

  File? _coverImage;
  List<File> _galleryImages = [];
  bool _isLoading = false;
  final List<String> _selectedAmenities = [];

  // New variable for coordinate picking
  LatLng? _selectedLatLng;

  final List<String> _availableAmenities = ['WiFi', 'AC', 'Security', 'Generator', 'Water Flow', 'Kitchen', 'Study Room'];

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _coverImage = File(pickedFile.path));
  }

  Future<void> _pickGalleryImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _galleryImages.addAll(pickedFiles.map((x) => File(x.path)));
      });
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      _galleryImages.removeAt(index);
    });
  }

  void _toggleAmenity(String amenity) {
    setState(() {
      if (_selectedAmenities.contains(amenity)) {
        _selectedAmenities.remove(amenity);
      } else {
        _selectedAmenities.add(amenity);
      }
    });
  }

  Future<void> _saveHostel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must be logged in as an agent.")));
       return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    if (_coverImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add a cover photo")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cloudinary = CloudinaryService();

      // 1. Upload Cover Image
      final coverUrl = await cloudinary.uploadProfilePicture(_coverImage!);
      if (coverUrl == null) throw "Cover image upload failed.";

      // 2. Upload Gallery Images
      List<String> galleryUrls = [];
      for (var img in _galleryImages) {
        final url = await cloudinary.uploadProfilePicture(img);
        if (url != null) galleryUrls.add(url);
      }

      // 3. Parse Numeric Fields
      final double? agentPrice = double.tryParse(_priceController.text.trim());
      final int? capacity = int.tryParse(_capacityController.text.trim());

      if (agentPrice == null || capacity == null) {
        throw "Invalid price or capacity format.";
      }

      final double platformFee = 50.0;
      final double finalPrice = agentPrice + platformFee;

      // 4. Save to Firestore
      await FirestoreService().addHostel({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': _selectedLatLng?.latitude, 
        'longitude': _selectedLatLng?.longitude,
        'price': finalPrice, 
        'agentPrice': agentPrice, 
        'platformFee': platformFee,
        'capacity': capacity,
        'description': _descController.text.trim(),
        'image': coverUrl,
        'gallery': galleryUrls, 
        'amenities': _selectedAmenities,
        'agentId': user.uid,
        'rating': 'New', 
        'ratingCount': 0, 
        'isFeatured': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hostel listed successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Add Hostel Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception:', '')}")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Hostel")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cover Image Picker
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _coverImage != null ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover) : null,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _coverImage == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), SizedBox(height: 8), Text("Add Cover Photo", style: TextStyle(color: Colors.grey))])
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Gallery Picker
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                   GestureDetector(
                    onTap: _pickGalleryImages,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Colors.blue), Text("Add Gallery", style: TextStyle(fontSize: 10))]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._galleryImages.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                         Container(
                           width: 100,
                           margin: const EdgeInsets.only(right: 8),
                           decoration: BoxDecoration(
                             borderRadius: BorderRadius.circular(12),
                             image: DecorationImage(image: FileImage(entry.value), fit: BoxFit.cover),
                           ),
                         ),
                         Positioned(
                           right: 0,
                           top: 0,
                           child: GestureDetector(
                             onTap: () => _removeGalleryImage(entry.key),
                             child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)),
                           ),
                         )
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Hostel Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.apartment)),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 16),

            // Updated Location Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: "Location Name", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () async {
                     final result = await Navigator.push(
                       context, 
                       MaterialPageRoute(builder: (_) => const LocationPickerPage())
                     );
                     if (result != null && result is LatLng) {
                        setState(() => _selectedLatLng = result);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location pinned!")));
                     }
                  },
                  icon: const Icon(Icons.map),
                  style: IconButton.styleFrom(backgroundColor: _selectedLatLng != null ? Colors.blue : Colors.grey[300]),
                )
              ],
            ),
            
            const SizedBox(height: 16),

            // Room Type / Capacity Selector
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: "Room Type", border: OutlineInputBorder(), prefixIcon: Icon(Icons.meeting_room)),
              value: int.tryParse(_capacityController.text),
              hint: const Text("Select Room Capacity"),
              items: List.generate(8, (index) => index + 1).map((num) {
                return DropdownMenuItem<int>(
                  value: num,
                  child: Text("$num in a room"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _capacityController.text = val.toString();
                });
              },
            ),

            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: "Price (GHS)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money), helperText: "Price per semester"),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                ),
                // Hidden Capacity Field (Managed by Dropdown)
                const SizedBox(width: 0, height: 0), 
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            const Text("Amenities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableAmenities.map((amenity) {
                final isSelected = _selectedAmenities.contains(amenity);
                return FilterChip(
                  label: Text(amenity),
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).primaryColor,
                  onSelected: (_) => _toggleAmenity(amenity),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHostel,
                style: ElevatedButton.styleFrom(
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   backgroundColor: Theme.of(context).primaryColor,
                   foregroundColor: Colors.white,
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("List Property", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
