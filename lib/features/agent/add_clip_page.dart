import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// import 'dart:io' show File; // Removed for web compatibility
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
    _musicPlayer.dispose();
    _captionController.dispose();
    _roomCapacityController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _videoFile = pickedFile;
        _isLoading = true; // Temporary loading for initialization
      });

      _videoController = kIsWeb 
        ? VideoPlayerController.networkUrl(Uri.parse(pickedFile.path))
        : VideoPlayerController.contentUri(Uri.file(pickedFile.path));
      // NOTE: using contentUri or networkUrl for file paths to avoid importing dart:io
      // Actually VideoPlayerController.networkUrl(Uri.file(...)) is safer if contentUri is not available or correct
      // improved fallback:
      if (!kIsWeb) {
         _videoController = VideoPlayerController.networkUrl(Uri.file(pickedFile.path));
      } else {
         _videoController = VideoPlayerController.networkUrl(Uri.parse(pickedFile.path));
      }
        
      _videoController!..initialize().then((_) {
          if (_selectedMusicId != 'original') {
            _videoController!.setVolume(0.0);
            _videoController!.addListener(_muteListener);
          }
          setState(() {
            _isLoading = false;
            _videoController!.play();
            _videoController!.setLooping(true);
          });
        });
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
            await _musicPlayer.setSourceUrl(track.url);
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
        'name': _selectedHostelName, // Display Title
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
        'rating': 4.5, // Default rating or could be fetched from data['rating'] in onTap
        'price': _hostelPrice, 
        'capacity': int.tryParse(_roomCapacityController.text.trim()) ?? 4,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clip posted successfully!")));
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Auth Required")));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Post New Clip", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        surfaceTintColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Video Preview / Picker
                GestureDetector(
                  onTap: () async {
                    if (_videoFile == null) {
                       _pickVideo();
                    } else if (_videoController != null) {
                       if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                          _musicPlayer.pause();
                       } else {
                          // Force sync
                          if (_selectedMusicId != 'original') {
                             _musicPlayer.resume();
                          }
                          _videoController!.play();
                       }
                       setState(() {}); 
                    }
                  },
                  child: Container(
                    height: 480, // Taller, more immersive
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                           blurRadius: 20,
                           offset: const Offset(0, 10)
                         )
                      ]
                    ),
                    child: _videoFile == null 
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey[800] : Colors.white,
                                  shape: BoxShape.circle
                                ),
                                child: Icon(Icons.video_call_rounded, size: 40, color: Colors.blue[600]),
                              ),
                              const SizedBox(height: 16),
                              Text("Tap to pick video", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                              Text("Supported formats: MP4, MOV", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13))
                            ],
                          )
                        : (_videoController != null && _videoController!.value.isInitialized)
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                  ),
                                  // Overlay play button if paused
                                  if (!_videoController!.value.isPlaying)
                                     Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                       child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                     ),
                                  // Change video button
                                  Positioned(
                                    top: 16, right: 16,
                                    child: IconButton(
                                      onPressed: _pickVideo,
                                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                                    ),
                                  )
                                ],
                              )
                            : const Center(child: CircularProgressIndicator()),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text("Details", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Hostel Selector
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService().getAgentHostels(user.uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    
                    final hostels = snapshot.data!.docs;
                    if (hostels.isEmpty) return const Text("No hostels found. Add a hostel first.");

                    return _buildStyledDropdown(
                      label: "Link to Hostel",
                      value: _selectedHostelId,
                      items: hostels.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['name'] ?? 'Unnamed', style: TextStyle(color: textColor)),
                          onTap: () {
                             _selectedHostelName = data['name'];
                             _hostelLocation = data['location'] ?? data['name'];
                             _hostelPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
                             
                             // Auto-populate capacity from hostel logic
                             final rawCap = data['capacity'];
                             if (rawCap != null) {
                               _roomCapacityController.text = rawCap.toString();
                             }
                          },
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedHostelId = val),
                      isDark: isDark,
                      icon: Icons.apartment_rounded
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Number of People per Room
                _buildStyledTextField(
                  controller: _roomCapacityController,
                  label: "People per Room",
                  icon: Icons.people_outline_rounded,
                  isDark: isDark,
                  isNumber: true,
                ),

                const SizedBox(height: 16),

                // Music Selector (Custom Picker)
                GestureDetector(
                  onTap: _showMusicPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.transparent : Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedMusicId == 'original' ? Colors.grey.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: Icon(Icons.music_note_rounded, color: _selectedMusicId == 'original' ? Colors.grey : Colors.blue),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Background Music", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500], fontSize: 12)), 
                              const SizedBox(height: 2),
                              Text(
                                _selectedMusicName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.grey : Colors.grey[400]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                _buildStyledTextField(
                  controller: _captionController,
                  label: "Write a caption...",
                  icon: Icons.edit_note_rounded,
                  isDark: isDark,
                  maxLines: 3,
                ),

                const SizedBox(height: 40),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                       colors: [Color(0xFF2E2AB7), Color(0xFF1BFFFF)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2E2AB7).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                    ]
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _postClip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, 
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: Text("Post Clip", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller, 
    required String label, 
    IconData? icon, 
    required bool isDark,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    final fillColor = isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.white;
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: icon != null ? Icon(icon, color: isDark ? Colors.grey[400] : Colors.blue[700]) : null,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: isDark ? BorderSide.none : BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
  
  Widget _buildStyledDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    required bool isDark,
    required IconData icon,
  }) {
     final fillColor = isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.white;
     return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.blue[700]),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: isDark ? BorderSide.none : BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
      await _player.setSourceUrl(url);
      await _player.resume();
      setState(() => _playingUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text("Select Music", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
               controller: _searchController,
               decoration: InputDecoration(
                 hintText: "Search artist, song, or genre...",
                 prefixIcon: const Icon(Icons.search),
                 filled: true,
                 fillColor: Colors.grey[100],
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                           decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                           child: const Icon(Icons.mic, color: Colors.black),
                         ),
                         title: const Text("Original Audio"),
                         subtitle: const Text("Keep video sound"),
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
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                    image: track.coverUrl != null 
                                      ? DecorationImage(image: NetworkImage(track.coverUrl!), fit: BoxFit.cover)
                                      : null,
                                  ),
                                  child: track.coverUrl == null ? const Icon(Icons.music_note, color: Colors.grey) : null,
                                ),
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(isPlaying ? 0.5 : 0.2), // Darken for visibility
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 28),
                                ),
                              ],
                            ),
                          ),
                          title: Text(track.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text("${track.artist}  •  ${track.genre}", maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                            ),
                            onPressed: () async {
                              // Save to DB so it persists for the clip metadata
                              await _musicService.saveTrackToDB(track);
                              widget.onSelect(track);
                            },
                            child: const Text("Select"),
                          ),
                        );
                     }).toList(),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
