import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/cloudinary_service.dart';

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
  final _descController = TextEditingController();

  File? _image;
  bool _isLoading = false;
  final List<String> _selectedAmenities = [];

  final List<String> _availableAmenities = ['WiFi', 'AC', 'Security', 'Generator', 'Water Flow', 'Kitchen', 'Study Room'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
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
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add an image")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload Image
      final imageUrl = await CloudinaryService().uploadProfilePicture(_image!); // Reusing the method, works for any image
      if (imageUrl == null) throw "Image upload failed";

      // 2. Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirestoreService().addHostel({
          'name': _nameController.text.trim(),
          'location': _locationController.text.trim(),
          'price': _priceController.text.trim(), // Storing as string for consistency with existing data, or parse to double
          'description': _descController.text.trim(),
          'image': imageUrl,
          'amenities': _selectedAmenities,
          'agentId': user.uid,
          'rating': 'New', // Default
          'isFeatured': false,
          'createdAt': DateTime.now(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hostel listed successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null,
                ),
                child: _image == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40), SizedBox(height: 8), Text("Add Cover Photo")])
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Hostel Name", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: "Location (e.g. Ayeduase)", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: "Price (GHS per semester)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            const Text("Amenities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _availableAmenities.map((amenity) {
                final isSelected = _selectedAmenities.contains(amenity);
                return FilterChip(
                  label: Text(amenity),
                  selected: isSelected,
                  onSelected: (_) => _toggleAmenity(amenity),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveHostel,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("List Property"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
