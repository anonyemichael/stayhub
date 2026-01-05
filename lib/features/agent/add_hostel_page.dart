// import 'dart:io' show File;
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
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _descController = TextEditingController();
  int _currentStep = 0;
  
  // Payout Config
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  String? _selectedBankCode;
  List<Map<String, dynamic>> _banks = [];

  // School Selection
  String? _selectedSchool;
  final List<String> _schools = ['UENR', 'UDS'];

  // Editing State
  String? _existingCoverUrl;
  List<String> _existingGalleryUrls = [];

  @override
  void initState() {
    super.initState();
    _loadBanks();
    if (widget.initialData != null) {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    _nameController.text = data['name'] ?? '';
    _locationController.text = data['location'] ?? '';
    _priceController.text = (data['price'] ?? '').toString();
    _capacityController.text = (data['capacity'] ?? '').toString();
    _descController.text = data['description'] ?? '';
    _selectedSchool = data['school'];
    
    // Coordinates
    if (data['latitude'] != null && data['longitude'] != null) {
      _selectedLatLng = LatLng(data['latitude'], data['longitude']);
    }

    // Images
    _existingCoverUrl = data['image'];
    if (data['gallery'] != null) {
      _existingGalleryUrls = List<String>.from(data['gallery']);
    }

    // Amenities
    if (data['amenities'] != null) {
      _selectedAmenities.addAll(List<String>.from(data['amenities']));
    }

    // Bank Details (if present)
    if (data['bank_details'] != null) {
      final bank = data['bank_details'];
      _selectedBankCode = bank['bank_code'];
      _accountNumberCtrl.text = bank['account_number'] ?? '';
      _accountNameCtrl.text = bank['account_name'] ?? '';
    }
  }

  Future<void> _loadBanks() async {
    final banks = await PaymentService().getBanks();
    if (mounted) setState(() => _banks = banks);
  }

  XFile? _coverImage;
  final List<XFile> _galleryImages = [];
  bool _isLoading = false;
  final List<String> _selectedAmenities = [];

  // New variable for coordinate picking
  LatLng? _selectedLatLng;

  final List<String> _availableAmenities = ['WiFi', 'AC', 'Security', 'Generator', 'Water Flow', 'Kitchen', 'Study Room', 'Gym', 'Laundry', 'TV Room', 'Balcony', 'Parking', 'CCTV', 'Fridge'];

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverImage = pickedFile;
        _existingCoverUrl = null; // Clear existing if new one picked
      });
    }
  }

  Future<void> _pickGalleryImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _galleryImages.addAll(pickedFiles);
      });
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      _galleryImages.removeAt(index);
    });
  }

  void _removeExistingGalleryImage(int index) {
    setState(() {
      _existingGalleryUrls.removeAt(index);
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

      // 1. Upload Cover Image (or use existing)
      String? coverUrl = _existingCoverUrl;
      if (_coverImage != null) {
         coverUrl = await cloudinary.uploadProfilePicture(_coverImage!);
      }
      
      if (coverUrl == null) throw "Cover image is required.";

      // 2. Upload New Gallery Images & Merge
      List<String> galleryUrls = [..._existingGalleryUrls];
      for (var img in _galleryImages) {
        final url = await cloudinary.uploadProfilePicture(img);
        if (url != null) galleryUrls.add(url);
      }

      // 3. Parse Numeric Fields
      final double? totalPrice = double.tryParse(_priceController.text.trim());
      final int? capacity = int.tryParse(_capacityController.text.trim());

      if (totalPrice == null || capacity == null) {
        throw "Invalid price or capacity format.";
      }

      // Updated: Fetch Global Commission Percentage (e.g. 2.0 for 2%)
      // This is deducted from the total price, the student pays exactly 'totalPrice'
      final double commissionPercent = await FirestoreService().getGlobalCommission();
      final double platformFee = (totalPrice * commissionPercent) / 100; 
      final double agentEarnings = totalPrice - platformFee;

      // --- PAYOUT SUBACCOUNT CREATION (Skip if editing and unchanged, or implement update logic) ---
      // For now, if editing, we only update if subaccount_code is missing or user explicitly changed bank details
      // Ideally, updating subaccount is complex. Let's assume for basic edit we might generate a new one if details changed.
      
      String? subAccountCode = widget.initialData?['subaccount_code'];
      Map<String, dynamic>? bankDetails = widget.initialData?['bank_details'];

      // Only create new subaccount if it's a new hostel OR bank details changed significantly
      bool bankDetailsChanged = _selectedBankCode != widget.initialData?['bank_details']?['bank_code'] || 
                                _accountNumberCtrl.text != widget.initialData?['bank_details']?['account_number'];

      if ((subAccountCode == null || bankDetailsChanged) && _selectedBankCode != null && _accountNumberCtrl.text.isNotEmpty) {
         final businessName = _accountNameCtrl.text.isNotEmpty ? _accountNameCtrl.text : _nameController.text;
         
         subAccountCode = await PaymentService().createSubAccount(
            businessName: businessName, 
            bankCode: _selectedBankCode!, 
            accountNumber: _accountNumberCtrl.text.trim(), 
            percentage: "0",
            email: user.email ?? "agent_${user.uid}@stayhub.com", 
            contactName: businessName
         );
         
         bankDetails = {
           'bank_code': _selectedBankCode,
           'account_number': _accountNumberCtrl.text.trim(),
           'account_name': businessName
         };
      }

      // 4. Save to Firestore
      final hostelData = {
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': _selectedLatLng?.latitude, 
        'longitude': _selectedLatLng?.longitude,
        'price': totalPrice, 
        'agentPrice': agentEarnings, 
        'platformFee': platformFee,
        'school': _selectedSchool,
        'subaccount_code': subAccountCode, 
        'bank_details': bankDetails,
        'capacity': capacity,
        'description': _descController.text.trim(),
        'contact': user.phoneNumber ?? "", 
        'image': coverUrl,
        'gallery': galleryUrls, 
        'amenities': _selectedAmenities,
        'agentId': user.uid,
        // Status resets to pending on specific edits? Maybe strictly for critical fields. 
        // For simplicity, let's keep status as is if editing, or 'pending' if new.
        'status': widget.hostelId != null ? (widget.initialData?['status'] ?? 'pending') : 'pending',
      };
      
      if (widget.hostelId == null) {
        // New Listing
        hostelData['rating'] = 'New';
        hostelData['ratingCount'] = 0;
        hostelData['isFeatured'] = false;
        hostelData['createdAt'] = FieldValue.serverTimestamp();
        await FirestoreService().addHostel(hostelData);
      } else {
        // Update Listing
        hostelData['updatedAt'] = FieldValue.serverTimestamp();
        await FirestoreService().updateHostel(widget.hostelId!, hostelData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.hostelId != null ? "Property updated!" : "Hostel listed successfully!")));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(context, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_currentStep == 0) _buildStep1(isDark),
                      if (_currentStep == 1) _buildStep2(isDark),
                      if (_currentStep == 2) _buildStep3(isDark),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
             onTap: () {
               if (_currentStep > 0) {
                 setState(() => _currentStep--);
               } else {
                 Navigator.pop(context);
               }
             },
             child: Icon(Icons.arrow_back_ios, size: 20, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.hostelId != null ? "Edit Property" : "List New Property", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: index <= _currentStep ? Colors.blueAccent : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEPS ---

  Widget _buildStep1(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerText("The Basics", "Start with a photo and location.", isDark),
        const SizedBox(height: 24),
        
        // Huge Cover Picker
        GestureDetector(
          onTap: _pickCoverImage,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
              image: _coverImage != null 
                ? DecorationImage(
                    image: (kIsWeb 
                      ? NetworkImage(_coverImage!.path)
                      : NetworkImage(_coverImage!.path)) as ImageProvider, 
                    fit: BoxFit.cover
                  ) 
                : (_existingCoverUrl != null 
                   ? DecorationImage(image: CachedNetworkImageProvider(_existingCoverUrl!), fit: BoxFit.cover)
                   : null),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!, style: (_coverImage == null && _existingCoverUrl == null) ? BorderStyle.solid : BorderStyle.none),
            ),
            child: (_coverImage == null && _existingCoverUrl == null)
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_a_photo_rounded, size: 48, color: Colors.blueAccent.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text("Add Cover Photo *", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontWeight: FontWeight.bold))
                  ])
                : Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(12),
                    child: const CircleAvatar(backgroundColor: Colors.white, radius: 16, child: Icon(Icons.edit, size: 16, color: Colors.black)),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel("Property Name", isDark, required: true),
        TextFormField(controller: _nameController, decoration: _modernInput("e.g. The comfort zone", Icons.apartment, isDark)),
        const SizedBox(height: 20),

        _buildLabel("University / Campus", isDark, required: true),
        DropdownButtonFormField<String>(
          value: _selectedSchool,
          decoration: _modernInput("Select School", Icons.school, isDark),
          items: _schools.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) => setState(() => _selectedSchool = val),
        ),
        const SizedBox(height: 20),

        _buildLabel("Location", isDark, required: true),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _locationController, decoration: _modernInput("City/Town", Icons.location_on_outlined, isDark))),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                 final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerPage()));
                 if (result != null && result is LatLng) {
                    setState(() => _selectedLatLng = result);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location pinned!")));
                 }
              },
              child: Container(
                height: 56, width: 56,
                decoration: BoxDecoration(color: _selectedLatLng != null ? Colors.green : Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.map_rounded, color: _selectedLatLng != null ? Colors.white : Colors.blueAccent),
              ),
            )
          ],
        ),
        const SizedBox(height: 20),
        
        _buildLabel("Description", isDark, required: true),
        TextFormField(controller: _descController, maxLines: 4, decoration: _modernInput("Tell students why they should stay here...", Icons.description_outlined, isDark)),
      ],
    );
  }

  Widget _buildStep2(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerText("Details & Amenities", "What makes your place special?", isDark),
        const SizedBox(height: 24),
        
        _buildLabel("Gallery", isDark),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
               GestureDetector(
                onTap: _pickGalleryImages,
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, color: Colors.blueAccent), SizedBox(height: 4), Text("Add", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
                ),
              ),

              // Existing Gallery Images
              ..._existingGalleryUrls.asMap().entries.map((entry) {
                return Stack(
                  children: [
                     Container(
                       width: 110, 
                       margin: const EdgeInsets.only(right: 12), 
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(20), 
                         image: DecorationImage(
                           image: CachedNetworkImageProvider(entry.value), 
                           fit: BoxFit.cover
                         )
                        )
                      ),
                     Positioned(top: 4, right: 16, child: GestureDetector(onTap: () => _removeExistingGalleryImage(entry.key), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white))))
                  ],
                );
              }),
              // New Gallery Images
              ..._galleryImages.asMap().entries.map((entry) {
                return Stack(
                  children: [
                     Container(
                       width: 110, 
                       margin: const EdgeInsets.only(right: 12), 
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(20), 
                         image: DecorationImage(
                           image: (kIsWeb 
                             ? NetworkImage(entry.value.path)
                             : NetworkImage(entry.value.path)) as ImageProvider, 
                           fit: BoxFit.cover
                         )
                        )
                      ),
                     Positioned(top: 4, right: 16, child: GestureDetector(onTap: () => _removeGalleryImage(entry.key), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white))))
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Capacity", isDark, required: true),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _modernInput("", Icons.people_outline, isDark),
                    initialValue: int.tryParse(_capacityController.text),
                    hint: const Text("Room Size", style: TextStyle(fontSize: 12)),
                    items: List.generate(8, (i) => i+1).map((n) => DropdownMenuItem(value: n, child: Text("$n in a room", overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _capacityController.text = v.toString()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Price (Semester)", isDark, required: true),
                  TextFormField(
                    controller: _priceController, 
                    keyboardType: TextInputType.number, 
                    decoration: _modernInput("₵ Price", Icons.payments_outlined, isDark)
                  )
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        _buildLabel("Amenities", isDark),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _availableAmenities.map((amenity) {
            final isSelected = _selectedAmenities.contains(amenity);
            return GestureDetector(
              onTap: () => _toggleAmenity(amenity),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent : (isDark ? Colors.white10 : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent),
                ),
                child: Text(amenity, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStep3(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerText("Finalize & Payout", "How students reach and pay you.", isDark),
        const SizedBox(height: 24),
        
        // Contact Phone Removed as per request (Wallet handles details)
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.account_balance, color: Colors.blueAccent)),
                const SizedBox(width: 12),
                const Text("Payout Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 16),
              Text("Verified funds will be sent here.", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedBankCode,
                isExpanded: true, // FIX OVERFLOW
                dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                decoration: _modernInput("Select Bank", Icons.account_balance_wallet_outlined, isDark),
                items: _banks.map((bank) {
                  return DropdownMenuItem(
                    value: bank['code'].toString(), 
                    child: Text(bank['name'], overflow: TextOverflow.ellipsis, maxLines: 1), // FIX OVERFLOW
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedBankCode = val),
              ),
              const SizedBox(height: 16),
              
              TextFormField(controller: _accountNumberCtrl, keyboardType: TextInputType.number, decoration: _modernInput("Account Number", Icons.numbers, isDark)),
              const SizedBox(height: 16),
              TextFormField(controller: _accountNameCtrl, decoration: _modernInput("Account Name", Icons.person_outline, isDark)),
            ],
          ),
        ),
      ],
    );
  }

  // --- CONTROLS ---

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () {
             // Step 1 Validation
             if (_currentStep == 0) {
               if (_coverImage == null && _existingCoverUrl == null) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add a cover photo *")));
                 return;
               }
                if (_nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter property name *")));
                  return;
                }
                if (_selectedSchool == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a school *")));
                  return;
                }
               if (_locationController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter city/town name *")));
                 return;
               }
               if (_selectedLatLng == null) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please pin the location on the map 📍")));
                 return;
               }
               if (_descController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter description *")));
                 return;
               }
               setState(() => _currentStep++);
               return;
             }

             // Step 2 Validation
             if (_currentStep == 1) {
               if (_capacityController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select capacity *")));
                 return;
               }
               if (_priceController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter price *")));
                 return;
               }
               setState(() => _currentStep++);
               return;
             }

             // Step 3 (Final)
             if (_currentStep == 2) {
               _saveHostel();
             }
          },
          style: ElevatedButton.styleFrom(
             backgroundColor: Colors.blueAccent,
             foregroundColor: Colors.white,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             elevation: 0,
          ),
          child: _isLoading 
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_currentStep == 2 ? (widget.hostelId != null ? "Save Changes" : "Publish Listing") : "Continue", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --- STYLING HELPERS ---

  Widget _headerText(String title, String sub, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text(sub, style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey[600])),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[800], fontFamily: 'Roboto'), // Ensure font is consistent
          children: [
            if (required) const TextSpan(text: " *", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  InputDecoration _modernInput(String hint, IconData icon, bool isDark) {
    return InputDecoration(
       hintText: hint,
       hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey[400]),
       prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey[500], size: 20),
       filled: true,
       fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
       border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
       focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
