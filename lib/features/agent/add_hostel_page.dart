import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/features/agent/location_picker_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stayhub/services/payment_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/app_config_service.dart';
import 'package:stayhub/features/agent/agent_add_rooms_page.dart';
import 'package:stayhub/core/school_utils.dart';
import 'package:stayhub/core/widgets/school_logo.dart';

class AddHostelPage extends StatefulWidget {
  final String? hostelId;
  final Map<String, dynamic>? initialData;

  const AddHostelPage({super.key, this.hostelId, this.initialData});

  @override
  State<AddHostelPage> createState() => _AddHostelPageState();
}

class _AddHostelPageState extends State<AddHostelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  
  int _currentStep = 0;
  final _paymentService = PaymentService();
  
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  String? _selectedBankCode;
  
  final _ownerAccountNumberCtrl = TextEditingController();
  final _ownerAccountNameCtrl = TextEditingController();
  String? _ownerBankCode;
  String? _ownerSubCodeFromProfile;

  List<Map<String, dynamic>> _banks = [];
  String _partnerType = 'agent';
  
  // Schools with Logos
  List<Map<String, dynamic>> _schoolsWithLogos = [];
  Map<String, dynamic>? _selectedSchoolData;

  XFile? _coverImage;
  final List<XFile> _galleryImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isGeneratingAI = false;
  LatLng? _selectedLatLng;

  final List<String> _selectedAmenities = [];
  final List<Map<String, dynamic>> _availableAmenities = [
    {'name': 'WiFi', 'icon': Icons.wifi_rounded},
    {'name': 'AC', 'icon': Icons.ac_unit_rounded},
    {'name': 'Laundry', 'icon': Icons.local_laundry_service_rounded},
    {'name': 'Security', 'icon': Icons.security_rounded},
    {'name': 'Kitchen', 'icon': Icons.kitchen_rounded},
    {'name': 'Water', 'icon': Icons.water_drop_rounded},
    {'name': 'Gym', 'icon': Icons.fitness_center_rounded},
    {'name': 'Study Room', 'icon': Icons.menu_book_rounded},
    {'name': 'Solar Power', 'icon': Icons.wb_sunny_rounded},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services_rounded},
  ];

  String? _existingCoverUrl;
  List<String> _existingGalleryUrls = [];

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _loadSchools();
    if (widget.initialData != null) {
      _loadInitialData();
    } else {
      _loadAgentProfile();
    }
  }

  Future<void> _loadSchools() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('schools').get();
      if (snapshot.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _schoolsWithLogos = snapshot.docs.map((doc) => {
              'id': doc.id,
              ...doc.data()
            }).toList();
          });
        }
      } else {
        final config = await AppConfigService().getConfig();
        final List<String> dynSchools = List<String>.from(config['available_schools'] ?? []);
        if (mounted) {
          setState(() {
            _schoolsWithLogos = dynSchools.map((s) => {'name': s, 'logo_url': null}).toList();
          });
        }
      }
      
      if (widget.initialData?['school'] != null && _schoolsWithLogos.isNotEmpty) {
        setState(() {
          final schoolName = widget.initialData?['school'].toString().trim().toUpperCase();
          _selectedSchoolData = _schoolsWithLogos.firstWhere(
            (s) => s['name'].toString().trim().toUpperCase() == schoolName,
            orElse: () => _schoolsWithLogos.first,
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading schools: $e");
    }
  }

  Future<void> _generateAIDescription() async {
    if (_nameController.text.isEmpty || _selectedSchoolData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hostel name and school required for AI")));
      return;
    }

    setState(() => _isGeneratingAI = true);
    await Future.delayed(const Duration(seconds: 2));
    
    final name = _nameController.text;
    final school = _selectedSchoolData!['name'];
    final amenities = _selectedAmenities.isEmpty ? "essential student facilities" : _selectedAmenities.join(", ");
    
    final description = "Experience modern student living at $name, located just minutes from $school. Our hostel is equipped with $amenities to ensure a comfortable and productive academic year. Perfect for students who value safety and convenience.";
    
    setState(() {
      _descController.text = description;
      _isGeneratingAI = false;
    });
  }

  Future<void> _addCustomAmenity() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Custom Amenity"),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "e.g. Roof Garden")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _selectedAmenities.add(controller.text.trim()));
                Navigator.pop(context);
              }
            }, 
            child: const Text("ADD")
          ),
        ],
      ),
    );
  }

  Future<void> _loadInitialData() async {
    final data = widget.initialData!;
    setState(() {
      _nameController.text = data['fullName'] ?? data['name'] ?? '';
      _locationController.text = data['location'] ?? '';
      _descController.text = data['description'] ?? '';
      _existingCoverUrl = data['image'];
      _existingGalleryUrls = List<String>.from(data['gallery'] ?? []);
      
      final List<dynamic> amenities = data['amenities'] ?? [];
      _selectedAmenities.addAll(amenities.cast<String>());
      
      if (data['latitude'] != null && data['longitude'] != null) {
        _selectedLatLng = LatLng(data['latitude'], data['longitude']);
      }
      
      _ownerAccountNumberCtrl.text = data['ownerAccountNumber'] ?? '';
      _ownerAccountNameCtrl.text = data['ownerBusinessName'] ?? '';
      _ownerBankCode = data['ownerBankCode'];
      _partnerType = data['partnerType'] ?? 'agent';
    });
  }

  Future<void> _loadAgentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('agents').doc(user.uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _partnerType = data['partnerType'] ?? 'agent';
        if (_partnerType == 'owner') {
          _ownerSubCodeFromProfile = data['paystack_subaccount_code'];
        }
        final bank = data['bankDetails'] as Map<String, dynamic>?;
        if (bank != null) {
          _selectedBankCode = bank['bankCode'];
          _accountNumberCtrl.text = bank['accountNumber'] ?? '';
          _accountNameCtrl.text = bank['accountName'] ?? '';
        }
      });
    }
  }

  Future<void> _loadBanks() async {
    final banks = await PaymentService().getBanks();
    if (mounted) setState(() => _banks = banks);
  }

  Future<void> _pickCoverImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _coverImage = image);
  }

  Future<void> _pickGalleryImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 70);
    if (images.isNotEmpty) setState(() => _galleryImages.addAll(images));
  }

  void _removeGalleryImage(int index) => setState(() => _galleryImages.removeAt(index));
  void _removeExistingGalleryImage(int index) => setState(() => _existingGalleryUrls.removeAt(index));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_coverImage == null && _existingCoverUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add a cover photo")));
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String coverUrl = _existingCoverUrl ?? '';
      if (_coverImage != null) {
        final url = await CloudinaryService().uploadImage(_coverImage!, folder: 'hostels');
        if (url != null) coverUrl = url;
      }

      List<String> galleryUrls = [..._existingGalleryUrls];
      for (var img in _galleryImages) {
        final url = await CloudinaryService().uploadImage(img, folder: 'hostels');
        if (url != null) galleryUrls.add(url);
      }

      
      String? ownerSubCode = widget.initialData?['ownerSubaccountCode'];

      // AUTOMATIC SUBACCOUNT CREATION FOR AGENT LISTINGS
      if (_partnerType == 'agent') {
        if (_ownerBankCode == null || _ownerAccountNumberCtrl.text.isEmpty) {
          throw "Owner bank details are required for agent listings.";
        }
        
        // Only create new one if details changed or missing
        final bool detailsChanged = widget.initialData?['ownerAccountNumber'] != _ownerAccountNumberCtrl.text || 
                                    widget.initialData?['ownerBankCode'] != _ownerBankCode;

        if (ownerSubCode == null || detailsChanged) {
          try {
            ownerSubCode = await _paymentService.createSubAccount(
              businessName: _ownerAccountNameCtrl.text.trim(),
              bankCode: _ownerBankCode!,
              accountNumber: _ownerAccountNumberCtrl.text.trim(),
              percentage: "0", // Platform takes its share via transactionCharge logic
              email: user.email ?? "owner@stayhub.app", // Fallback email
            );
          } catch (e) {
            throw "Payout Setup Failed: $e";
          }
        }
      } else if (_partnerType == 'owner') {
        ownerSubCode ??= _ownerSubCodeFromProfile;
        if (ownerSubCode == null) {
          throw "Please set up your Payout Account in your profile first before adding a hostel.";
        }
      }

      final hostelData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descController.text.trim(),
        'image': coverUrl,
        'gallery': galleryUrls,
        'amenities': _selectedAmenities,
        'school': _selectedSchoolData?['name'] ?? '',
        'latitude': _selectedLatLng?.latitude,
        'longitude': _selectedLatLng?.longitude,
        'agentId': widget.initialData?['agentId'] ?? user.uid,
        'status': 'active',
        'isActive': true,
        'price': 0, 
        // 3-Way Split Data
        'ownerSubaccountCode': ownerSubCode,
        'ownerBusinessName': _ownerAccountNameCtrl.text.trim(),
        'ownerAccountNumber': _ownerAccountNumberCtrl.text.trim(),
        'ownerBankCode': _ownerBankCode,
        'partnerType': _partnerType, 
      };
      
      String finalHostelId;
      if (widget.hostelId == null) {
        hostelData['createdAt'] = FieldValue.serverTimestamp();
        finalHostelId = await FirestoreService().addHostel(hostelData);
      } else {
        hostelData['updatedAt'] = FieldValue.serverTimestamp();
        await FirestoreService().updateHostel(widget.hostelId!, hostelData);
        finalHostelId = widget.hostelId!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hostel Saved! Now add room prices."), backgroundColor: Colors.blue));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AgentAddRoomsPage(hostelId: finalHostelId, initialRooms: widget.initialData?['rooms'])));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumHeader(context, isDark, textColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_currentStep == 0) _buildStepIdentity(isDark, textColor),
                      if (_currentStep == 1) _buildStepMedia(isDark, textColor),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_currentStep > 0) {
                setState(() => _currentStep--);
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.hostelId != null ? "Edit Listing" : "List Property", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(2, (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i <= _currentStep ? const Color(0xFF2563EB) : (isDark ? Colors.white10 : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIdentity(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Property Identity", "Start with your property name and school."),
        const SizedBox(height: 24),
        _buildModernField(_nameController, "Hostel Name", Icons.home_work_rounded, isDark),
        const SizedBox(height: 20),
        _buildSchoolSelector(isDark),
        const SizedBox(height: 20),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _selectedLatLng != null ? Colors.green.withOpacity(0.05) : const Color(0xFF2563EB).withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _selectedLatLng != null ? Colors.green.withOpacity(0.3) : const Color(0xFF2563EB).withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Pin Location (Optional)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _selectedLatLng != null ? Colors.green : const Color(0xFF2563EB))),
                    const Text("Students find properties with pins 2x faster.", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              _buildMapBtn(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildModernField(_locationController, "Street Address / Area", Icons.location_on_rounded, isDark),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Amenities", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor)),
            TextButton.icon(onPressed: _addCustomAmenity, icon: const Icon(Icons.add_rounded, size: 16), label: const Text("Custom", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _availableAmenities.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity['name']);
            return FilterChip(
              label: Text(amenity['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) _selectedAmenities.add(amenity['name']);
                  else _selectedAmenities.remove(amenity['name']);
                });
              },
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              avatar: Icon(amenity['icon'], size: 14, color: isSelected ? Colors.white : Colors.grey),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey[200]!)),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text("Description", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor)),
             TextButton.icon(
                onPressed: _isGeneratingAI ? null : _generateAIDescription,
                icon: _isGeneratingAI 
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                    : const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.blueAccent),
                label: const Text("✨ Auto-Generate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                style: TextButton.styleFrom(backgroundColor: Colors.blueAccent.withOpacity(0.05), padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildModernField(_descController, "Tell students about the environment...", Icons.description_rounded, isDark, maxLines: 5),
        const SizedBox(height: 20),
        
        if (_partnerType == 'agent') ...[
          const SizedBox(height: 40),
          _buildSectionTitle("Owner Payout Setup", "Pick the owner's bank/MoMo for automated payouts."),
          const SizedBox(height: 20),
          
          // Owner Bank Selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _ownerBankCode,
                hint: Text("Select Owner's Bank", style: TextStyle(color: Colors.grey[500])),
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: _banks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank['code'],
                    child: Text(bank['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _ownerBankCode = val),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernField(_ownerAccountNumberCtrl, "Owner Account/MoMo Number", Icons.account_balance_wallet_rounded, isDark, isNumber: true),
          const SizedBox(height: 16),
          _buildModernField(_ownerAccountNameCtrl, "Owner Account Name (Business/Personal)", Icons.business_rounded, isDark),
          const SizedBox(height: 8),
          const Text(
            "The base price will be sent here automatically. No manual transfers needed.",
            style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  Widget _buildStepMedia(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Visual Showcase", "Add high-quality photos to attract students."),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 200, width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
              image: (_coverImage != null || _existingCoverUrl != null) 
                  ? DecorationImage(
                      image: _coverImage != null 
                          ? FileImage(File(_coverImage!.path)) 
                          : CachedNetworkImageProvider(_existingCoverUrl!) as ImageProvider, 
                      fit: BoxFit.cover
                    ) : null,
            ),
            child: (_coverImage == null && _existingCoverUrl == null)
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_rounded, size: 40, color: Color(0xFF2563EB)), SizedBox(height: 12), Text("Add Cover Photo", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))])
                : const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(12), child: CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(Icons.edit, size: 16, color: Colors.black)))),
          ),
        ),
        const SizedBox(height: 32),
        Text("Property Gallery", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: textColor)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: _galleryImages.length + _existingGalleryUrls.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildAddGalleryBtn(isDark);
            final actualIndex = index - 1;
            if (actualIndex < _existingGalleryUrls.length) {
              return _buildGalleryPreview(_existingGalleryUrls[actualIndex], true, actualIndex);
            } else {
              final newIndex = actualIndex - _existingGalleryUrls.length;
              return _buildGalleryPreview(_galleryImages[newIndex].path, false, newIndex);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity, height: 60,
        child: ElevatedButton(
          onPressed: _isLoading ? null : (_currentStep < 1 ? () => setState(() => _currentStep++) : _submit),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_currentStep < 1 ? "NEXT STEP" : "SAVE & ADD ROOM PRICES", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildSchoolSelector(bool isDark) {
    return InkWell(
      onTap: () => _showSchoolPicker(isDark),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            if (_selectedSchoolData != null) ...[
              SchoolLogo(
                logoUrl: SchoolUtils.getSchoolLogo(_selectedSchoolData!['name'], {
                  if (_selectedSchoolData!['logo_url'] != null) _selectedSchoolData!['name'].toString().toUpperCase(): _selectedSchoolData!['logo_url'].toString(),
                  if (_selectedSchoolData!['logo'] != null) _selectedSchoolData!['name'].toString().toUpperCase(): _selectedSchoolData!['logo'].toString(),
                }),
                size: 32,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 16),
            ] else ...[
              const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 24),
              const SizedBox(width: 16),
            ],
            Expanded(child: Text(_selectedSchoolData?['name'] ?? "Select Campus / University", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _selectedSchoolData == null ? Colors.grey : null))),
            const Icon(Icons.expand_more_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showSchoolPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _schoolsWithLogos.length,
        itemBuilder: (context, index) {
          final school = _schoolsWithLogos[index];
          final String? logoUrl = SchoolUtils.getSchoolLogo(school['name'], {
            if (school['logo_url'] != null) school['name'].toString().toUpperCase(): school['logo_url'].toString(),
            if (school['logo'] != null) school['name'].toString().toUpperCase(): school['logo'].toString(),
          });
          return ListTile(
            leading: SchoolLogo(
              logoUrl: logoUrl,
              size: 32,
              fit: BoxFit.contain,
            ),
            title: Text(school['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              setState(() => _selectedSchoolData = school);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, bool isDark, {int maxLines = 1, bool isNumber = false}) {
    return TextFormField(
      controller: controller, maxLines: maxLines, keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20), filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildMapBtn() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerPage()));
        if (result != null && result is LatLng) setState(() => _selectedLatLng = result);
      },
      child: Container(
        height: 56, width: 56, decoration: BoxDecoration(color: _selectedLatLng != null ? Colors.green : const Color(0xFF2563EB), borderRadius: BorderRadius.circular(18)),
        child: Icon(_selectedLatLng != null ? Icons.check_circle_rounded : Icons.map_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAddGalleryBtn(bool isDark) {
    return InkWell(onTap: _pickGalleryImages, child: Container(decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2))), child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2563EB))));
  }

  Widget _buildGalleryPreview(String path, bool isExisting, int index) {
    return Stack(children: [Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), image: DecorationImage(image: isExisting ? CachedNetworkImageProvider(path) : FileImage(File(path)) as ImageProvider, fit: BoxFit.cover))), Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => isExisting ? _removeExistingGalleryImage(index) : _removeGalleryImage(index), child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white))))]);
  }
}
