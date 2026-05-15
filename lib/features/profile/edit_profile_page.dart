import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:stayhub/services/app_config_service.dart';
import 'package:stayhub/services/local_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:stayhub/core/image_utils.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  
  Map<String, dynamic>? _selectedSchoolData;
  String? _selectedLevel;
  final List<Map<String, dynamic>> _schools = [];
  final List<String> _levels = ['100', '200', '300', '400', '500', '600', 'Post-Graduate', 'Other'];

  bool _isLoading = true;
  bool _isSaving = false;
  String _userCollection = 'users';
  XFile? _imageFile;
  String? _photoUrl;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_uid == null) return;

    try {
      final schoolsFuture = FirebaseFirestore.instance.collection('schools').get();
      
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      _userCollection = 'users';
      
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance.collection('agents').doc(_uid).get();
        _userCollection = 'agents';
      }
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance.collection('admins').doc(_uid).get();
        _userCollection = 'admins';
      }

      final schoolsSnap = await schoolsFuture;
      if (mounted) {
        setState(() {
          _schools.clear();
          _schools.addAll(schoolsSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
          
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            _populateFields(data);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _nameController.text = data['fullName'] ?? data['name'] ?? '';
    _phoneController.text = data['phoneNumber'] ?? '';
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    _selectedLevel = data['level']?.toString();
    _photoUrl = data['photoUrl'];
    _bioController.text = data['bio'] ?? data['description'] ?? '';
    
    final schoolName = data['school']?.toString().trim().toUpperCase();
    if (schoolName != null && _schools.isNotEmpty) {
      // Try robust matching
      try {
        _selectedSchoolData = _schools.firstWhere(
          (s) {
            final sName = s['name']?.toString().trim().toUpperCase();
            return sName == schoolName;
          },
          orElse: () => _schools.firstWhere(
            (s) => s['name']?.toString().trim().toUpperCase().contains(schoolName) ?? false,
            orElse: () => {},
          ),
        );
        
        if (_selectedSchoolData?.isEmpty ?? true) {
          _selectedSchoolData = null;
        }
      } catch (e) {
        _selectedSchoolData = null;
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) setState(() => _imageFile = pickedFile);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
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
        'school': _selectedSchoolData?['name'],
        'level': _userCollection == 'agents' ? null : _selectedLevel,
        'bio': _bioController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (newPhotoUrl != null) dataToUpdate['photoUrl'] = newPhotoUrl;

      await FirebaseFirestore.instance.collection(_userCollection).doc(_uid).set(dataToUpdate, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
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
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 4),
                              image: DecorationImage(
                                image: _imageFile != null 
                                    ? FileImage(File(_imageFile!.path)) 
                                    : (_photoUrl != null && _photoUrl!.isNotEmpty 
                                        ? CachedNetworkImageProvider(ImageUtils.getSecureUrl(_photoUrl!)) 
                                        : const AssetImage('assets/logo/logo.png')) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: const CircleAvatar(
                                backgroundColor: Color(0xFF2563EB),
                                radius: 18,
                                child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Personal Info", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 24),
                          _buildInput("Full Name", _nameController, Icons.person_rounded, isDark),
                          const SizedBox(height: 20),
                          _buildSchoolSelector(isDark),
                          const SizedBox(height: 20),
                          if (_userCollection != 'agents') ...[
                             _buildLevelSelector(isDark),
                             const SizedBox(height: 20),
                          ],
                          _buildInput("Phone Number", _phoneController, Icons.phone_android_rounded, isDark, keyboardType: TextInputType.phone),
                          const SizedBox(height: 20),
                          _buildInput("Professional Bio", _bioController, Icons.article_rounded, isDark, maxLines: 3),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSchoolSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("University / Institution", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showSchoolPicker(isDark),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                if (_selectedSchoolData != null) ...[
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: SchoolUtils.getSchoolLogo(_selectedSchoolData!['name'] ?? '', {} ) ?? '', 
                      height: 28, width: 28, 
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(Icons.school, size: 20)
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(_selectedSchoolData?['name'] ?? "Select Institution", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                const Icon(Icons.expand_more_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSchoolPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _schools.length,
        itemBuilder: (context, index) {
          final school = _schools[index];
          final String? logo = SchoolUtils.getSchoolLogo(school['name'] ?? '', {});
          return ListTile(
            leading: ClipOval(
              child: CachedNetworkImage(
                imageUrl: logo ?? '', 
                height: 32, width: 32, 
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.school_rounded, color: Color(0xFF2563EB))
              ),
            ),
            title: Text(school['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              setState(() => _selectedSchoolData = school);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildLevelSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Academic Level", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(18)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLevel,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: _levels.map((level) => DropdownMenuItem(value: level, child: Text(level, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              onChanged: (val) => setState(() => _selectedLevel = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon, bool isDark, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
      ],
    );
  }
}
