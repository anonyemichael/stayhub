import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:stayhub/services/local_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:stayhub/core/image_utils.dart';
import 'package:stayhub/core/widgets/school_logo.dart';

class AgentEditProfilePage extends StatefulWidget {
  const AgentEditProfilePage({super.key});

  @override
  State<AgentEditProfilePage> createState() => _AgentEditProfilePageState();
}

class _AgentEditProfilePageState extends State<AgentEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  
  String _partnerType = 'agent';
  List<String> _selectedSchools = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
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
    _fetchAgentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgentData() async {
    if (_uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('agents').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? data['phoneNumber'] ?? '';
          _emailController.text = data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
          _bioController.text = data['bio'] ?? data['description'] ?? '';
          _partnerType = data['partnerType'] ?? 'agent';
          _selectedSchools = List<String>.from(data['schoolsOfOperation'] ?? []);
          _photoUrl = data['photoUrl'];
          _isLoading = false;
        });
        LocalCacheService.save(LocalCacheService.KEY_USER_PROFILE, data);
      }
    } catch (e) {
      debugPrint("Error fetching agent: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        setState(() => _imageFile = pickedFile);
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSchools.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one school of operation")));
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      String? newPhotoUrl;
      if (_imageFile != null) {
        newPhotoUrl = await CloudinaryService().uploadProfilePicture(_imageFile!);
      }

      final dataToUpdate = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'partnerType': _partnerType,
        'schoolsOfOperation': _selectedSchools,
        'bio': _bioController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (newPhotoUrl != null) {
        dataToUpdate['photoUrl'] = newPhotoUrl;
      }

      await FirebaseFirestore.instance.collection('agents').doc(_uid).update(dataToUpdate);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Professional profile updated!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
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
                                        ? CachedNetworkImageProvider(_photoUrl!) 
                                        : const AssetImage('assets/logo/logo.png')) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
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
                          const Text("Business Identity", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 24),
                          _buildInput("Business / Full Name", _nameController, Icons.business_rounded, isDark),
                          const SizedBox(height: 20),
                          _buildInput("Contact Phone", _phoneController, Icons.phone_android_rounded, isDark, keyboardType: TextInputType.phone),
                          const SizedBox(height: 32),
                          
                          const Text("Partner Role", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildRoleOption("agent", "Agent", Icons.support_agent_rounded, isDark),
                              const SizedBox(width: 12),
                              _buildRoleOption("owner", "Owner", Icons.home_work_rounded, isDark),
                            ],
                          ),
                          const SizedBox(height: 32),

                          const Text("Schools of Operation", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          _buildSchoolsWrap(isDark),
                          const SizedBox(height: 32),

                          const Text("Professional Bio", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          const SizedBox(height: 12),
                          _buildInput("About your business...", _bioController, Icons.article_rounded, isDark, maxLines: 4),
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

  Widget _buildRoleOption(String type, String label, IconData icon, bool isDark) {
    final isSelected = _partnerType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _partnerType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.w900, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolsWrap(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('schools').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
        final docs = snapshot.data!.docs;
        
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? '';
            final String? schoolLogo = SchoolUtils.getSchoolLogo(name, {});
            final isSelected = _selectedSchools.contains(name);
            
            return FilterChip(
              label: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) _selectedSchools.add(name);
                  else _selectedSchools.remove(name);
                });
              },
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              avatar: SchoolLogo(
                logoUrl: schoolLogo,
                size: 20,
                fit: BoxFit.contain,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey[200]!)),
            );
          }).toList(),
        );
      },
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
          validator: (v) => v!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }
}
