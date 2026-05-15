import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io' show File;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:stayhub/data/music_library.dart';
import 'package:stayhub/services/music_service.dart'; // NEW IMPORT

class AddClipPage extends StatefulWidget {
  const AddClipPage({super.key});

  @override
  State<AddClipPage> createState() => _AddClipPageState();
}

class _AddClipPageState extends State<AddClipPage> {
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  final _captionController = TextEditingController();
  final _roomCapacityController = TextEditingController(text: "4");
  
  String? _selectedHostelName;
  String? _selectedHostelId;
  
  // Rooms for the selected hostel
  List<Map<String, dynamic>> _rooms = [];
  String? _selectedRoomId;
  String? _selectedRoomName;
  
  
  // NEW: Store selected track info
  MusicTrack? _selectedTrack;
  String _selectedMusicId = 'original';
  String _selectedMusicName = 'Original Audio';
  
  double _hostelPrice = 0;
  String _hostelLocation = "";
  
  bool _isLoading = false;

  final AudioPlayer _musicPlayer = AudioPlayer();

  // ADDED: Listener to enforce muting
  void _muteListener() {
    if (_selectedMusicId != 'original' && _videoController != null && _videoController!.value.volume > 0) {
      _videoController!.setVolume(0.0);
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_muteListener);
    _videoController?.dispose();
    _musicPlayer.stop();
    _musicPlayer.dispose();
    _captionController.dispose();
    _roomCapacityController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      // DISPOSE OLD CONTROLLER TO PREVENT MEMORY LEAK
      if (_videoController != null) {
        _videoController!.removeListener(_muteListener);
        await _videoController!.dispose();
        _videoController = null;
      }

      setState(() {
        _videoFile = pickedFile;
        _isLoading = true; // Temporary loading for initialization
      });

      try {
        if (kIsWeb) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(pickedFile.path));
        } else {
          _videoController = VideoPlayerController.file(File(pickedFile.path));
        }
          
        await _videoController!.initialize().timeout(const Duration(seconds: 15));
        
        if (_selectedMusicId != 'original') {
          _videoController!.setVolume(0.0);
          _videoController!.addListener(_muteListener);
          
          // START MUSIC PLAYER IF ALREADY SELECTED
          await _musicPlayer.stop();
          if (_selectedTrack != null) {
            await _musicPlayer.setSource(UrlSource(_selectedTrack!.url));
            await _musicPlayer.setReleaseMode(ReleaseMode.loop);
            await _musicPlayer.resume();
          }
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _videoController!.play();
            _videoController!.setLooping(true);
          });
        }
      } catch (e) {
        debugPrint("Video init error: $e");
        if (mounted) {
          setState(() {
            _isLoading = false;
            // Keep _videoFile so user can still try to upload it
            _videoController = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Preview unavailable for this format. You can still try to 'Post' it anyway!"),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _showMusicPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MusicPickerSheet(
        onSelect: (track) async {
          setState(() {
            _selectedTrack = track;
            _selectedMusicId = track.id;
            _selectedMusicName = "${track.title} - ${track.artist}";
          });
          
          // Update Preview Sound
          if (_videoController != null) {
            await _videoController!.setVolume(0.0); // Mute video
            
            // Just in case it hasn't been added yet
            _videoController!.removeListener(_muteListener);
            _videoController!.addListener(_muteListener);

            await _musicPlayer.stop();
            await _musicPlayer.setSource(UrlSource(track.url));
            await _musicPlayer.setReleaseMode(ReleaseMode.loop);
            await _musicPlayer.resume();
          }
          
          Navigator.pop(context);
        },
        onSelectOriginal: () async {
          setState(() {
            _selectedTrack = null;
            _selectedMusicId = 'original';
            _selectedMusicName = 'Original Audio';
          });
          
          // Restore Original Sound
          if (_videoController != null) {
            _videoController!.removeListener(_muteListener);
            await _videoController!.setVolume(1.0);
            await _musicPlayer.stop();
          }
          
           Navigator.pop(context);
        }
      ),
    );
  }

  Future<void> _postClip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a video")));
      return;
    }
    if (_selectedHostelName == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please link a hostel")));
       return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload Video
      final videoUrl = await CloudinaryService().uploadVideo(_videoFile!);
      if (videoUrl == null) throw "Video upload failed";

      // 2. Save to Firestore 'clips'
      await FirebaseFirestore.instance.collection('clips').add({
        'url': videoUrl,
        'name': _selectedHostelName ?? "Hostel Tour", // Display Title
        'location': _hostelLocation, // Link for Search
        'hostelId': _selectedHostelId,
        'caption': _captionController.text.trim(),
        
        // Music Metadata
        'music': _selectedMusicId,
        'musicTitle': _selectedTrack?.title,
        'musicArtist': _selectedTrack?.artist,
        'musicUrl': _selectedTrack?.url,
        
        'agentId': user.uid,
        'agentPhoto': user.photoURL,
        'likes': [],
        'likeCount': 0,
        'commentCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().millisecondsSinceEpoch, // Local sync field
        'rating': 4.5, 
        'price': _hostelPrice / 1.10, // STORE BASE PRICE (Clips Feed adds 10% dynamically)
        'capacity': int.tryParse(_roomCapacityController.text.trim()) ?? 4,
        'roomId': _selectedRoomId,
        'roomName': _selectedRoomName ?? "Standard Room",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clip posted successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Clip Upload Error: $e");
      String errorMsg = e.toString();
      if (errorMsg.contains("Size") || errorMsg.contains("too large")) {
        errorMsg = "Video is too large. Please use a shorter clip (under 50MB).";
      } else if (errorMsg.contains("format")) {
        errorMsg = "Unsupported video format. Please use MP4 or WebM.";
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Failed: $errorMsg"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Auth Required")));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Video Preview (TikTok Style)
          if (_videoFile != null && _videoController != null && _videoController!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else if (_videoFile != null)
            // SHOW THIS IF VIDEO IS PICKED BUT PREVIEW FAILED (e.g. Tecno/Android Crop issue)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [const Color(0xFF1E293B), const Color(0xFF334155)] 
                      : [const Color(0xFFCBD5E1), const Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, size: 60, color: Colors.blue),
                      ),
                      const SizedBox(height: 20),
                      const Text("Video Ready", style: TextStyle(color: Colors.blue, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "This format is ready for upload!\n(Preview limited on this device)",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
                      : [const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_camera_back_rounded, size: 80, color: Colors.blue.withOpacity(0.3)),
                      const SizedBox(height: 24),
                      Text("Select your masterpiece", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // Top Bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  const Text("Studio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -1)),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),
          ),

          // Bottom Control Panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, -10))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Creator Tools: Music & Video
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Text("CREATOR TOOLS", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCreatorButton(
                                onTap: _showMusicPicker,
                                label: _selectedMusicId == 'original' ? "Add Music" : _selectedMusicName,
                                icon: Icons.music_note_rounded,
                                color: const Color(0xFFF43F5E), // Rose
                                isDark: isDark,
                                isActive: _selectedMusicId != 'original',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCreatorButton(
                                onTap: _pickVideo,
                                label: _videoFile == null ? "Pick Video" : "Replace",
                                icon: Icons.videocam_rounded,
                                color: const Color(0xFF0EA5E9), // Sky
                                isDark: isDark,
                                isActive: _videoFile != null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text("LINK PROPERTY", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  // Hostel Selector
                  StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService().getAgentHostels(user.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      final hostels = snapshot.data!.docs;
                      
                      return _buildPremiumDropdown(
                        value: _selectedHostelId,
                        hint: "Select a Hostel",
                        icon: Icons.apartment_rounded,
                        items: hostels.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            onTap: () {
                               _selectedHostelName = data['name'];
                               _hostelLocation = data['location'] ?? data['name'];
                               final double basePrice = (data['price'] as num?)?.toDouble() ?? 0.0;
                               _hostelPrice = basePrice * 1.10;
                               _rooms = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
                               if (_rooms.isEmpty) {
                                 final rawCap = data['capacity'];
                                 if (rawCap != null) _roomCapacityController.text = rawCap.toString();
                               }
                            },
                            child: Text(data['name'] ?? 'Unnamed', style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() {
                          _selectedHostelId = val;
                          _selectedRoomId = null;
                        }),
                        isDark: isDark,
                      );
                    },
                  ),

                  if (_selectedHostelId != null && _rooms.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPremiumDropdown(
                      value: _selectedRoomId,
                      hint: "Select Room Type",
                      icon: Icons.meeting_room_rounded,
                        items: _rooms.map<DropdownMenuItem<String>>((room) {
                          final rName = (room['name'] ?? room['type'] ?? room['roomType'])?.toString() ?? "Standard Room";
                          
                          // Smart capacity parsing
                          int? parsedCap;
                          if (rName.contains('-in-a-room')) {
                            parsedCap = int.tryParse(rName.split('-').first);
                          }
                          
                          final rCap = (room['capacity'] ?? room['slots'] ?? room['beds'] ?? parsedCap)?.toString() ?? "4";
                          
                          return DropdownMenuItem<String>(
                            value: room['id']?.toString() ?? rName,
                            onTap: () {
                              _selectedRoomName = rName;
                              _roomCapacityController.text = rCap;
                              final double basePrice = (room['price'] as num?)?.toDouble() ?? _hostelPrice / 1.10; 
                              _hostelPrice = basePrice * 1.10; // Apply 10% Commission
                            },
                            child: Text("$rName ($rCap in a room)", style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                      onChanged: (val) => setState(() => _selectedRoomId = val as String?),
                      isDark: isDark,
                    ),
                  ],

                  const SizedBox(height: 12),
                  _buildPremiumTextField(
                    controller: _captionController,
                    hint: "Add a catchy caption...",
                    icon: Icons.notes_rounded,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),
                  _buildPremiumTextField(
                    controller: _roomCapacityController,
                    hint: "Room Capacity (e.g. 4)",
                    icon: Icons.groups_rounded,
                    isDark: isDark,
                    isNumber: true,
                  ),

                  const SizedBox(height: 32),
                  
                  // Post Button
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _videoFile == null) ? null : _postClip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("PUBLISH CLIP", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreatorButton({required VoidCallback onTap, required String label, required IconData icon, required Color color, required bool isDark, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color.withOpacity(0.3) : Colors.transparent, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive ? color : (isDark ? Colors.white10 : Colors.black12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isActive ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]), size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label.length > 12 ? "${label.substring(0, 9)}..." : label,
              style: TextStyle(
                color: isActive ? color : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumDropdown({required String? value, required String hint, required IconData icon, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
          icon: const Icon(Icons.expand_more_rounded, color: Colors.grey),
          decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({required TextEditingController controller, required String hint, required IconData icon, required bool isDark, bool isNumber = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          icon: Icon(icon, color: Colors.blueAccent, size: 20),
        ),
      ),
    );
  }
}

class _MusicPickerSheet extends StatefulWidget {
  final Function(MusicTrack) onSelect;
  final VoidCallback onSelectOriginal;
  const _MusicPickerSheet({required this.onSelect, required this.onSelectOriginal});

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  final AudioPlayer _player = AudioPlayer();
  final _musicService = MusicService(); 
  final _searchController = TextEditingController();
  
  String? _playingUrl;
  
  // Cache the future for stability
  late Future<List<MusicTrack>> _musicFuture;

  @override
  void initState() {
    super.initState();
    _musicFuture = _musicService.fetchTrendingMusic();
  }

  @override
  void dispose() {
    _player.stop(); 
    _player.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearch(String query) {
    setState(() {
      _musicFuture = _musicService.searchMusic(query);
    });
  }

  Future<void> _preview(String url) async {
    if (_playingUrl == url) {
      await _player.stop();
      setState(() => _playingUrl = null);
    } else {
      await _player.stop(); 
      await _player.setSource(UrlSource(url));
      await _player.resume();
      setState(() => _playingUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Text("Select Music", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)),
                const Spacer(),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54)
                  ), 
                  onPressed: () => Navigator.pop(context)
                )
              ],
            ),
          ),
          
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: TextField(
               controller: _searchController,
               style: TextStyle(color: isDark ? Colors.white : Colors.black),
               decoration: InputDecoration(
                 hintText: "Search artist, song, or genre...",
                 hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                 prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white38 : Colors.grey),
                 filled: true,
                 fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16),
               ),
               onSubmitted: _onSearch,
               textInputAction: TextInputAction.search,
            ),
          ),

          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<MusicTrack>>(
              future: _musicFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                   return Center(child: Text("Error loading music: ${snapshot.error}"));
                }

                final tracks = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                     // Show Original Option only if not searching deeply (optional logic, kept simple here)
                     if (_searchController.text.isEmpty)
                       ListTile(
                         leading: Container(
                           padding: const EdgeInsets.all(10),
                           decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                           child: Icon(Icons.mic_rounded, color: isDark ? Colors.white70 : Colors.black87),
                         ),
                         title: Text("Original Audio", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                         subtitle: Text("Keep video sound", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
                         onTap: widget.onSelectOriginal,
                       ),
                     if (_searchController.text.isEmpty) const Divider(),
                     
                     if (tracks.isEmpty)
                       const Padding(
                         padding: EdgeInsets.all(20.0),
                         child: Center(child: Text("No songs found.")),
                       ),

                       ...tracks.map((track) {
                        final isPlaying = _playingUrl == track.url;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          leading: GestureDetector(
                            onTap: () => _preview(track.url),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    image: track.coverUrl != null 
                                      ? DecorationImage(image: NetworkImage(track.coverUrl!), fit: BoxFit.cover)
                                      : null,
                                  ),
                                  child: track.coverUrl == null ? Icon(Icons.music_note_rounded, color: isDark ? Colors.white38 : Colors.grey) : null,
                                ),
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(isPlaying ? 0.6 : 0.3), // Darken for visibility
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                ),
                              ],
                            ),
                          ),
                          title: Text(track.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text("${track.artist}  •  ${track.genre}", style: TextStyle(color: isDark ? Colors.white38 : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.white : Colors.black,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                            ),
                            onPressed: () async {
                              // Save to DB so it persists for the clip metadata
                              await _musicService.saveTrackToDB(track);
                              widget.onSelect(track);
                            },
                            child: const Text("Select", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
