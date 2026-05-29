import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/core/image_utils.dart';

class AgentAddRoomsPage extends StatefulWidget {
  final String hostelId;
  final List<dynamic>? initialRooms;

  const AgentAddRoomsPage({super.key, required this.hostelId, this.initialRooms});

  @override
  State<AgentAddRoomsPage> createState() => _AgentAddRoomsPageState();
}

class _AgentAddRoomsPageState extends State<AgentAddRoomsPage> {
  final List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> _commonRoomAmenities = [
    'AC', 'Fan', 'Private Washroom', 'Study Table', 'Balcony', 'Wardrobe', 'WiFi', 'Fridge'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRooms != null) {
      for (var r in widget.initialRooms!) {
        _rooms.add(Map<String, dynamic>.from(r));
      }
    }
  }

  void _showRoomSheet({int? editIndex}) {
    final bool isEditing = editIndex != null;
    final Map<String, dynamic>? existingRoom = isEditing ? _rooms[editIndex] : null;

    String selectedType = existingRoom?['type'] ?? '1-in-a-room';
    String selectedPeriod = existingRoom?['paymentPeriod'] ?? 'semester';
    final priceCtrl = TextEditingController(text: existingRoom?['price']?.toString() ?? '');
    final qtyCtrl = TextEditingController(text: existingRoom?['quantity']?.toString() ?? '');
    List<String> selectedAmenities = List<String>.from(existingRoom?['amenities'] ?? []);
    List<XFile> newRoomImages = [];
    List<String> existingImageUrls = existingRoom?['images'] != null 
        ? List<String>.from(existingRoom?['images']) 
        : (existingRoom?['image'] != null ? [existingRoom!['image']] : []);
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text(isEditing ? "Edit Room Type" : "Define Room Type", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const Text("Set visuals, pricing, and amenities for this room.", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 24),
                
                GestureDetector(
                  onTap: () async {
                    final List<XFile> imgs = await _picker.pickMultiImage(imageQuality: 70);
                    if (imgs.isNotEmpty) setModalState(() => newRoomImages.addAll(imgs));
                  },
                  child: Container(
                    height: 180, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.1), width: 2),
                    ),
                    child: (newRoomImages.isEmpty && existingImageUrls.isEmpty) 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, color: Colors.blueAccent, size: 32), 
                            SizedBox(height: 8), 
                            Text("Upload Room Photos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueAccent))
                          ]
                        )
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(12),
                          children: [
                            ...existingImageUrls.map((url) => _buildThumbnail(url, isUrl: true, onDelete: () => setModalState(() => existingImageUrls.remove(url)))),
                            ...newRoomImages.map((file) => _buildThumbnail(file.path, isUrl: false, onDelete: () => setModalState(() => newRoomImages.remove(file)))),
                            _buildAddMoreThumbnail(() async {
                               final List<XFile> imgs = await _picker.pickMultiImage(imageQuality: 70);
                               if (imgs.isNotEmpty) setModalState(() => newRoomImages.addAll(imgs));
                            }),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildFieldLabel("Room Configuration"),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: ['1-in-a-room', '2-in-a-room', '3-in-a-room', '4-in-a-room', 'Self-Contained']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold))))
                      .toList(),
                  onChanged: (val) => setModalState(() => selectedType = val!),
                  decoration: _inputDecoration(null),
                ),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel("Price (GHS)"),
                          TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: _inputDecoration("GHS ")),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel("Total Slots"),
                          TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: _inputDecoration(null)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _buildFieldLabel("Payment Period"),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildPeriodOption('monthly', 'Monthly', Icons.calendar_view_day_rounded, selectedPeriod, setModalState, (v) => selectedPeriod = v),
                      _buildPeriodOption('semester', 'Semester', Icons.calendar_view_month_rounded, selectedPeriod, setModalState, (v) => selectedPeriod = v),
                      _buildPeriodOption('academic_year', 'Full Year', Icons.school_rounded, selectedPeriod, setModalState, (v) => selectedPeriod = v),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildFieldLabel("Room Amenities"),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonRoomAmenities.map((amenity) {
                    final isSelected = selectedAmenities.contains(amenity);
                    return ChoiceChip(
                      label: Text(amenity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
                      selected: isSelected,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) selectedAmenities.add(amenity);
                          else selectedAmenities.remove(amenity);
                        });
                      },
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3))),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isUploading ? null : () async {
                      if (priceCtrl.text.isEmpty || qtyCtrl.text.isEmpty) return;
                      setModalState(() => isUploading = true);
                      
                      List<String> finalImageUrls = List<String>.from(existingImageUrls);
                      if (newRoomImages.isNotEmpty) {
                        for (var img in newRoomImages) {
                          final url = await CloudinaryService().uploadImage(img, folder: 'rooms');
                          if (url != null) finalImageUrls.add(url);
                        }
                      }
 
                      // Extract numeric capacity from type (e.g., '2-in-a-room' -> 2)
                      int capacity = 1;
                      if (selectedType.contains('-in-a-room')) {
                        capacity = int.tryParse(selectedType.split('-').first) ?? 1;
                      } else if (selectedType == 'Self-Contained') {
                        capacity = 1; // Default for self-contained, can be adjusted
                      }

                      final roomData = {
                        'type': selectedType,
                        'capacity': capacity,
                        'price': double.parse(priceCtrl.text),
                        'paymentPeriod': selectedPeriod,
                        'quantity': int.parse(qtyCtrl.text),
                        'available': existingRoom?['available'] ?? int.parse(qtyCtrl.text),
                        'images': finalImageUrls,
                        'amenities': selectedAmenities,
                      };

                      setState(() {
                        if (isEditing) {
                          _rooms[editIndex] = roomData;
                        } else {
                          _rooms.add(roomData);
                        }
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: isUploading ? const CircularProgressIndicator(color: Colors.white) : Text(isEditing ? "UPDATE ROOM TYPE" : "CONFIRM ROOM TYPE", style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
    );
  }

  InputDecoration _inputDecoration(String? prefix) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      prefixText: prefix,
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _finish() async {
    if (_rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one room type to publish")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      double minPrice = (_rooms.first['price'] as num).toDouble();
      for (var room in _rooms) {
        final price = (room['price'] as num).toDouble();
        if (price < minPrice) minPrice = price;
      }

      await FirebaseFirestore.instance.collection('hostels').doc(widget.hostelId).update({
        'rooms': _rooms,
        'price': minPrice,
        'has_rooms_configured': true,
        'status': 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✨ Property Inventory Updated!"), backgroundColor: Colors.green));
        Navigator.pop(context);
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
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: const Text("Room Inventory", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Inventory Suite", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                Text("Manage pricing, photos, and amenities for your rooms.", style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: _rooms.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) => _buildRoomCard(_rooms[index], index, cardColor, isDark),
                  ),
          ),
          _buildBottomAction(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_rounded, size: 64, color: Colors.blueAccent),
          ),
          const SizedBox(height: 24),
          const Text("Inventory is empty", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Text("Add your first room type to get started.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, int index, Color cardColor, bool isDark) {
    final List<dynamic> amenities = room['amenities'] ?? [];
    final List<dynamic> images = room['images'] ?? (room['image'] != null ? [room['image']] : []);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              image: images.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(images.first), fit: BoxFit.cover) : null,
            ),
            child: images.isEmpty ? const Icon(Icons.image_not_supported_rounded, color: Colors.blueAccent, size: 20) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room['type'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  "GHS ${room['price']} ${_periodLabel(room['paymentPeriod'])}",
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                if (amenities.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: amenities.take(3).map((a) => Icon(_getAmenityIcon(a.toString()), size: 12, color: Colors.grey)).toList(),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _showRoomSheet(editIndex: index),
                icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => setState(() => _rooms.removeAt(index)),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String path, {required bool isUrl, required VoidCallback onDelete}) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: isUrl 
              ? CachedNetworkImageProvider(ImageUtils.getSecureUrl(path)) 
              : (kIsWeb ? NetworkImage(path) : FileImage(File(path))) as ImageProvider,
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMoreThumbnail(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
        ),
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.blueAccent, size: 24),
      ),
    );
  }

  IconData _getAmenityIcon(String name) {
    switch (name.toLowerCase()) {
      case 'ac': return Icons.ac_unit_rounded;
      case 'fan': return Icons.mode_fan_off_rounded;
      case 'wifi': return Icons.wifi_rounded;
      case 'fridge': return Icons.kitchen_rounded;
      case 'study table': return Icons.desk_rounded;
      case 'wardrobe': return Icons.door_sliding_rounded;
      case 'balcony': return Icons.balcony_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }

  String _periodLabel(String? period) {
    switch (period) {
      case 'monthly': return '/ month';
      case 'semester': return '/ semester';
      case 'academic_year': return '/ year';
      default: return '/ semester';
    }
  }

  Widget _buildPeriodOption(
    String value,
    String label,
    IconData icon,
    String selected,
    StateSetter setModalState,
    ValueChanged<String> onSelect,
  ) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => onSelect(value)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : Colors.grey,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 60,
            child: OutlinedButton.icon(
              onPressed: () => _showRoomSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text("ADD ROOM TYPE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE & PUBLISH", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
