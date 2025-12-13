import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stayhub/services/cloudinary_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _isLoading = true;
  bool _isSaving = false;
  String _userCollection = 'users';
  File? _imageFile;
  String? _photoUrl;
  bool _isPickingImage = false; // Flag to prevent multiple image pickers

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_uid == null) return;

    try {
      DocumentSnapshot? userDoc;
      if ((await FirebaseFirestore.instance.collection('admins').doc(_uid).get()).exists) {
        userDoc = await FirebaseFirestore.instance.collection('admins').doc(_uid).get();
        _userCollection = 'admins';
      } else if ((await FirebaseFirestore.instance.collection('agents').doc(_uid).get()).exists) {
        userDoc = await FirebaseFirestore.instance.collection('agents').doc(_uid).get();
        _userCollection = 'agents';
      } else {
        userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
        _userCollection = 'users';
      }

      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['fullName'] ?? data['name'] ?? '';
          _phoneController.text = data['phoneNumber'] ?? '';
          _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
          _photoUrl = data['photoUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching user: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isPickingImage) return; // Prevent multiple instances
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      String? newPhotoUrl;
      if (_imageFile != null) {
        newPhotoUrl = await CloudinaryService().uploadProfilePicture(_imageFile!);
      }
      
      Map<String, dynamic> dataToUpdate = {
        'fullName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (newPhotoUrl != null) {
        dataToUpdate['photoUrl'] = newPhotoUrl;
      }

      await FirebaseFirestore.instance.collection(_userCollection).doc(_uid).set(dataToUpdate, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? _buildSkeletonLoader(context)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: bgColor,
                  elevation: 0,
                  iconTheme: IconThemeData(color: textColor),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: _imageFile != null 
                                ? FileImage(_imageFile!) 
                                : (_photoUrl != null && _photoUrl!.isNotEmpty 
                                    ? NetworkImage(_photoUrl!) 
                                    : const AssetImage('assets/logo/logo.png')) as ImageProvider,
                            onBackgroundImageError: (_, __) { /* Handles NetworkImage failure */ },
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: CircleAvatar(
                                backgroundColor: isDark ? Colors.cyanAccent : Colors.blueAccent,
                                radius: 20,
                                child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildInput(context, "Full Name", _nameController, Icons.person_outline),
                          const SizedBox(height: 20),
                          _buildInput(context, "Email Address", _emailController, Icons.email_outlined, readOnly: true),
                          const SizedBox(height: 20),
                          _buildInput(context, "Phone Number", _phoneController, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.cyanAccent : Colors.blueAccent,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInput(BuildContext context, String label, TextEditingController controller, IconData icon, {bool readOnly = false, int maxLines = 1, TextInputType? keyboardType}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final glassColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? Colors.transparent : glassColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: textColor.withValues(alpha: 0.1)),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            validator: (value) => value!.isEmpty && !readOnly ? "Required" : null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: textColor.withValues(alpha: 0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(height: 120, width: 120, decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle)),
            const SizedBox(height: 40),
            for(int i=0; i<3; i++)
              Container(margin: const EdgeInsets.only(bottom: 24), height: 60, width: double.infinity, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(16))),
          ],
        ),
      ),
    );
  }
}
