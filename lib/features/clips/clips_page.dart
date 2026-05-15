import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/app_config_service.dart';
import 'package:stayhub/core/widgets/skeleton.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:stayhub/data/music_library.dart';
class ClipsPage extends StatefulWidget {
  final bool isActive;
  final bool isAdmin; 
  final List<QueryDocumentSnapshot>? initialClips;
  final int initialIndex;
  final String? filterAgentId;

  const ClipsPage({
    super.key, 
    this.isActive = true, 
    this.isAdmin = false,
    this.initialClips,
    this.initialIndex = 0,
    this.filterAgentId,
  });

  @override
  State<ClipsPage> createState() => _ClipsPageState();
}

class _ClipsPageState extends State<ClipsPage> with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isAppActive = true;
  
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, AudioPlayer> _audioPlayers = {}; 
  final Set<int> _initializedIndices = {};
  final Set<int> _initializingIndices = {};

  final FirestoreService _firestoreService = FirestoreService();
  List<QueryDocumentSnapshot> _clips = [];
  bool _isLoading = true;
  bool _isMuted = true; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    if (widget.initialClips != null && widget.initialClips!.isNotEmpty) {
      _clips = List.from(widget.initialClips!); // Defensive copy
      _isLoading = false;
      // Pre-init
      _initControllerAtIndex(_currentIndex);
      _initControllerAtIndex(_currentIndex + 1);
    } else {
      _loadClips();
    }
  }

  Future<void> _loadClips() async {
    // SECURITY: If we were given initial clips, NEVER load the global feed
    if (widget.initialClips != null) return;

    Stream<QuerySnapshot> stream;
    if (widget.filterAgentId != null) {
      stream = FirebaseFirestore.instance
          .collection('clips')
          .where('agentId', isEqualTo: widget.filterAgentId)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      stream = _firestoreService.getClips(limit: 20);
    }

    final snapshot = await stream.first;
    if (mounted) {
       setState(() {
         _clips = snapshot.docs;
         _isLoading = false;
       });
       if (_clips.isNotEmpty) {
         _onPageChanged(_currentIndex); 
         _initControllerAtIndex(_currentIndex);
         _initControllerAtIndex(_currentIndex + 1);
       }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    try {
      for (var controller in _controllers.values) {
        controller.dispose();
      }
      for (var player in _audioPlayers.values) {
        player.dispose(); // Dispose Audio
      }
    } catch (e) {
      debugPrint("Error disposing controllers: $e");
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      _playCurrent();
    } else {
      _isAppActive = false;
      _pauseCurrent();
    }
  }
  
  @override
  void didUpdateWidget(ClipsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // Re-initialize current and neighbors when returning to the page
        _initControllerAtIndex(_currentIndex);
        _initControllerAtIndex(_currentIndex + 1);
        _initControllerAtIndex(_currentIndex - 1);
        _playCurrent();
      } else {
        _pauseCurrent();
        // Aggressively free memory if not active
        _disposeAllControllers();
      }
    }
  }

  void _disposeAllControllers() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (var player in _audioPlayers.values) {
      player.dispose();
    }
    _audioPlayers.clear();
    _initializedIndices.clear();
    _initializingIndices.clear();
  }

  void _playCurrent() {
    if (!mounted) return;
    if (widget.isActive && _isAppActive && _controllers.containsKey(_currentIndex)) {
      final controller = _controllers[_currentIndex];
      final audio = _audioPlayers[_currentIndex];
      
      final data = _clips[_currentIndex].data() as Map<String, dynamic>;
      final musicId = data['music'] as String? ?? 'original';

      if (controller != null && controller.value.isInitialized) {
         if (musicId != 'original') {
            controller.setVolume(0.0); // Force mute
            if (!_isMuted && audio != null) {
               // RESUME AUDIO and then start video immediately
               audio.resume().then((_) {
                  if (mounted && _currentIndex == _clips.indexOf(_clips[_currentIndex])) {
                     controller.play();
                  }
               });
            } else {
               audio?.pause();
               controller.play();
            }
         } else {
            controller.setVolume(_isMuted ? 0.0 : 1.0);
            audio?.stop();
            controller.play();
         }
      }
    }
  }

  void _pauseCurrent() {
    if (_controllers.containsKey(_currentIndex)) {
      _controllers[_currentIndex]?.pause();
    }
    if (_audioPlayers.containsKey(_currentIndex)) {
      _audioPlayers[_currentIndex]?.pause();
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      _controllers[_currentIndex]?.pause();
      // Only seek back if it's far away, otherwise keep position for better "go back" feel
      if ((index - _currentIndex).abs() > 2) {
         _controllers[_currentIndex]?.seekTo(Duration.zero);
      }
      _audioPlayers[_currentIndex]?.stop(); 
    }

    _currentIndex = index;
    _playCurrent();

    // Aggressive Pre-caching & Garbage Collection
    _manageResources(index);
  }

  void _manageResources(int index) {
    // 1. Garbage Collection - Dispose controllers far from current index
    final keysToRemove = <int>[];
    _controllers.forEach((key, controller) {
      if (key < index - 2 || key > index + 2) {
        keysToRemove.add(key);
      }
    });

    for (var key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _audioPlayers[key]?.dispose(); 
      _audioPlayers.remove(key);
      _initializedIndices.remove(key);
    }

    // 2. Pre-initialize immediate neighbors
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _currentIndex == index) {
        _initControllerAtIndex(index + 1);
        _initControllerAtIndex(index + 2); // Preload next 2
        _initControllerAtIndex(index - 1);
      }
    });

    // 3. Pre-cache next 5 video files to disk (No memory impact, only disk/network)
    if (!kIsWeb) {
      for (int i = index + 1; i <= index + 5; i++) {
         if (i < _clips.length) {
            final data = _clips[i].data() as Map<String, dynamic>;
            final url = (data['url'] ?? data['videoUrl']) as String?;
            if (url != null) {
               DefaultCacheManager().downloadFile(url); // Non-blocking background download
            }
         }
      }
    }
  }

  Future<void> _initControllerAtIndex(int index) async {
    if (index < 0 || index >= _clips.length) return;
    if (_controllers.containsKey(index) || _initializingIndices.contains(index)) return;

    // Check if it's too far from current index
    if ((index - _currentIndex).abs() > 2) return;

    _initializingIndices.add(index);
    final data = _clips[index].data() as Map<String, dynamic>; 
    var url = (data['url'] ?? data['videoUrl']) as String?;
    final musicId = data['music'] as String? ?? 'original';

    if (url == null || url.trim().isEmpty) {
      debugPrint("ClipsPage: Skip index $index - URL is null or empty");
      _initializingIndices.remove(index);
      return;
    }
    
    url = url.trim();
    if (url.startsWith('http:')) url = url.replaceFirst('http:', 'https:');
    
    debugPrint("ClipsPage: Initializing video at index $index with URL: $url");

      VideoPlayerController controller;
      try {
        if (kIsWeb) {
           // Skip cache manager on Web, it causes crashes and fails to resolve local paths
           controller = VideoPlayerController.networkUrl(Uri.parse(url));
        } else {
           // Try cache first (Wait up to 2 seconds for cache check to keep UI responsive)
           FileInfo? fileInfo;
           try {
              fileInfo = await DefaultCacheManager().getFileFromCache(url).timeout(const Duration(seconds: 2));
           } catch (_) {}
           
           // Re-check if still relevant after async call
           if (!mounted || (index - _currentIndex).abs() > 2) {
              _initializingIndices.remove(index);
              return;
           }

           if (fileInfo != null && fileInfo.file.path.isNotEmpty) {
             debugPrint("ClipsPage: Using cached file for index $index: ${fileInfo.file.path}");
             controller = VideoPlayerController.file(fileInfo.file);
           } else {
              // If not in cache or invalid path, trigger a download for next time but play from network now
              if (url.startsWith('http') && url.length > 8) {
                DefaultCacheManager().downloadFile(url);
                controller = VideoPlayerController.networkUrl(Uri.parse(url));
              } else {
                debugPrint("ClipsPage: Invalid URL format for index $index: $url");
                _initializingIndices.remove(index);
                return;
              }
           }
        }

        _controllers[index] = controller; 
        
        await controller.initialize();
        await controller.setLooping(true);
      
      // Re-check again
      if (!mounted || !_controllers.containsKey(index)) {
        _initializingIndices.remove(index);
        controller.dispose();
        _controllers.remove(index);
        return;
      }

      _initializingIndices.remove(index);
      // SETUP AUDIO if Custom Music
      var track = MusicLibrary.getTrackById(musicId);
      if (track == null && data['musicUrl'] != null && data['musicUrl'].toString().trim().isNotEmpty) {
         track = MusicTrack(
           id: musicId, 
           title: data['musicTitle'] ?? 'Song', 
           artist: data['musicArtist'] ?? 'Artist', 
           genre: 'Music', 
           url: data['musicUrl'].toString().trim()
         );
      }

      if (track != null) {
         try {
           final player = AudioPlayer();
           await player.setSourceUrl(track.url).timeout(const Duration(seconds: 5));
           await player.setReleaseMode(ReleaseMode.loop);
           await player.setVolume(1.0);
           
           if (mounted && (index >= _currentIndex - 1 && index <= _currentIndex + 1)) {
             _audioPlayers[index] = player;
           } else {
             player.dispose();
           }
         } catch (e) {
           debugPrint("Error initializing audio for video $index: $e");
         }
      }

      // Initial Volume Set
      if (musicId != 'original') {
         await controller.setVolume(0.0);
      } else {
         await controller.setVolume(_isMuted ? 0.0 : 1.0);
      }
      
      if (mounted) {
        setState(() {
          _initializedIndices.add(index);
        });
        if (index == _currentIndex) {
           _playCurrent();
        }
      }
    } catch (e) {
      debugPrint("Error initializing video $index: $e");
    } finally {
      _initializingIndices.remove(index);
    }
  }

  void _toggleGlobalMute() {
    setState(() => _isMuted = !_isMuted);
    
    // Apply immediate effect
    final controller = _controllers[_currentIndex];
    final audio = _audioPlayers[_currentIndex];
    
    final data = _clips[_currentIndex].data() as Map<String, dynamic>;
    final musicId = data['music'] as String? ?? 'original';
    
    if (musicId != 'original') {
       // Custom Music Case
       if (_isMuted) {
         audio?.pause();
       } else {
         audio?.resume();
       }
       controller?.setVolume(0.0); // KEEP VIDEO MUTED
    } else {
       // Original Audio Case
       controller?.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  Future<void> _deleteClip(String clipId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Clip?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteClip(clipId);
        if (mounted) {
          setState(() {
            // Clean up resources for this index
            _controllers[index]?.dispose();
            _controllers.remove(index);
            _audioPlayers[index]?.dispose();
            _audioPlayers.remove(index);
            _initializedIndices.remove(index);
            _clips.removeAt(index);
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clip deleted")));
          if (_clips.isEmpty) {
             _isLoading = false; 
          } else {
             _onPageChanged(_currentIndex >= _clips.length ? _clips.length - 1 : _currentIndex);
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
       return const Scaffold(
         backgroundColor: Colors.black,
         body: Center(child: CircularProgressIndicator(color: Colors.white24))
       );
    }

    if (_isLoading && _clips.isEmpty) {
       return const Scaffold(
         backgroundColor: Colors.black, 
         body: Skeleton(height: double.infinity, width: double.infinity, borderRadius: 0)
       );
    }
    
    if (_clips.isEmpty) {
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text('No clips available', style: TextStyle(color: Colors.white54)),
          ),
        );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
        allowImplicitScrolling: true,
        itemCount: _clips.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final data = _clips[index].data() as Map<String, dynamic>;
          data['id'] = _clips[index].id;
          
          final controller = _controllers[index];
          final isInitialized = _initializedIndices.contains(index);

          // Safely handle likes as either a List or an int (legacy data)
          dynamic rawLikes = data['likes'];
          List<dynamic> likesList = [];
          if (rawLikes is List) {
            likesList = rawLikes;
          } else if (rawLikes is int) {
            // If it's an int, we don't have the UIDs, but we can't crash.
            // We'll pass an empty list and use the count for display if needed.
          }

          return VideoPlayerItem(
             key: ValueKey("video_${data['id']}"), 
             videoData: data,
             controller: controller, 
             audioPlayer: _audioPlayers[index],
             isInitialized: isInitialized,
             isMuted: _isMuted,
             likes: likesList,
             onMuteToggle: _toggleGlobalMute,
             isAdmin: widget.isAdmin,
             onDelete: () => _deleteClip(data['id'], index),
          );
        },
      ),
    );
  }
}

class VideoPlayerItem extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final VideoPlayerController? controller;
  final AudioPlayer? audioPlayer;
  final bool isInitialized;
  final bool isMuted;
  final List<dynamic> likes;
  final VoidCallback onMuteToggle;
  final VoidCallback onDelete;
  final bool isAdmin;

  const VideoPlayerItem({
    super.key, 
    required this.videoData, 
    required this.controller, 
    this.audioPlayer,
    required this.isInitialized,
    required this.isMuted,
    required this.likes,
    required this.onMuteToggle,
    required this.onDelete,
    this.isAdmin = false,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> with SingleTickerProviderStateMixin {
  late AnimationController _playPauseController;
  bool _showIcon = false;

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    super.dispose();
  }

  void _onVideoTap() {
    if (widget.controller == null || !widget.isInitialized) return;

    setState(() {
      _showIcon = true;
    });

    if (widget.controller!.value.isPlaying) {
      widget.controller!.pause();
      widget.audioPlayer?.pause();
    } else {
      if (!widget.isMuted) {
        widget.audioPlayer?.resume();
      }
      widget.controller!.play();
    }

    _playPauseController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _showIcon = false;
          });
        }
      });
    });
  }

  String _getRoomDisplayText(Map<String, dynamic> data) {
    final name = (data['roomName'] ?? data['name'] ?? data['type'])?.toString();
    
    // Smart capacity parsing from name fallback
    int? parsedCap;
    if (name != null && name.contains('-in-a-room')) {
      parsedCap = int.tryParse(name.split('-').first);
    }
    
    final cap = (data['capacity'] ?? data['slots'] ?? data['beds'] ?? parsedCap)?.toString() ?? "4";
    
    if (name == null || name == "null" || name.isEmpty || name == "Hostel Tour") {
      return "$cap in a room";
    }
    return "$name ($cap in a room)";
  }

  @override
  Widget build(BuildContext context) {
    // RESOLVE MUSIC AESTHETICS
    String musicDisplay = 'Original Audio';
    final trackId = widget.videoData['music'];
    if (trackId != null && trackId != 'original') {
       final track = MusicLibrary.getTrackById(trackId);
       if (track != null) {
          musicDisplay = "${track.title} • ${track.artist}";
       } else if (widget.videoData['musicTitle'] != null) {
          // Fallback to embedded metadata
          musicDisplay = "${widget.videoData['musicTitle']} • ${widget.videoData['musicArtist'] ?? 'Artist'}";
       }
    }

    final firestoreService = FirestoreService();

    // Safe parsing for price with Commission logic (matching the rest of the app)
    final double rawVal = (widget.videoData['price'] as num?)?.toDouble() ?? 0.0;
    // We check if it's likely a base price (less than what a commission price would be)
    // Actually, to be safe and consistent, we apply the 10% on top of whatever is in the 'price' field 
    // IF we are in the clips page (since agents often upload base prices).
    // The user explicitly said it's showing base price, so we multiply by 1.10.
    final double finalPrice = rawVal * 1.10;
    
    final String priceStr = finalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Layer (Full Screen Cover)
        Container(
          color: Colors.black,
          child: Center(
             child: (widget.isInitialized && widget.controller != null)
                 ? GestureDetector(
                     onTap: _onVideoTap,
                     child: Stack(
                       alignment: Alignment.center,
                       children: [
                         SizedBox.expand(
                           child: FittedBox(
                             fit: BoxFit.cover,
                             child: SizedBox(
                               width: widget.controller!.value.size.width,
                               height: widget.controller!.value.size.height,
                               child: VideoPlayer(widget.controller!),
                             ),
                           ),
                         ),
                         // Play/Pause Icon Overlay
                         if (_showIcon || (widget.controller != null && !widget.controller!.value.isPlaying))
                           AnimatedBuilder(
                             animation: _playPauseController,
                             builder: (context, child) {
                               bool isPaused = widget.controller != null && !widget.controller!.value.isPlaying;
                               
                               return Opacity(
                                 opacity: isPaused ? 0.8 : (1.0 - _playPauseController.value),
                                 child: Transform.scale(
                                   scale: isPaused ? 1.0 : (1.0 + _playPauseController.value),
                                   child: Container(
                                     padding: const EdgeInsets.all(20),
                                     decoration: BoxDecoration(
                                       color: Colors.black45,
                                       shape: BoxShape.circle,
                                       border: Border.all(color: Colors.white24, width: 2),
                                     ),
                                     child: Icon(
                                       isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                       color: Colors.white,
                                       size: 70,
                                     ),
                                   ),
                                 ),
                               );
                             },
                           ),
                       ],
                     ),
                   )
                  : const Skeleton(height: double.infinity, width: double.infinity, borderRadius: 0),
          ),
        ),
        
        // 2. Stylish Gradient Overlay
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.transparent, Colors.black54, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.6, 0.85, 1.0],
                ),
              ),
            ),
          ),
        ),

        // Mute/Unmute Button (Top Right)
        // Mute/Unmute Button (Top Right)
         Positioned(
          top: 50, // Moved down slightly to avoid status bar overlap
          right: 20,
          child: GestureDetector(
            onTap: widget.onMuteToggle,
            child: Container(
              padding: const EdgeInsets.all(12), // Increased padding
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6), // Darker background for contrast
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5), // Added border for visibility
              ),
              child: Icon(
                widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 28, // Increased icon size
              ),
            ),
          ),
        ),

        // 3. Info Layer with Glassmorphsim Feel
        Positioned(
          left: 16,
          bottom: 100,
          right: 80, 
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                // Tags
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _getRoomDisplayText(widget.videoData), 
                            style: const TextStyle(color: Colors.white, fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("${widget.videoData['rating'] ?? 4.5} ★", style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                 const SizedBox(height: 16),
                
                if (widget.videoData['caption'] != null && widget.videoData['caption'].toString().isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 8.0),
                     child: Text(
                       widget.videoData['caption'],
                       style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),

                // Name
                Text(
                  widget.videoData['name'] ?? "Hostel Tour",
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 22, 
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)]
                  ),
                ),
                const SizedBox(height: 4),
                
                // Location
                Row(children: [
                   const Icon(Icons.location_on, color: Colors.blueAccent, size: 16), 
                   const SizedBox(width: 4), 
                   Expanded(
                     child: Text(widget.videoData['location'] ?? "Unknown Location", 
                       style: const TextStyle(color: Colors.white70, fontSize: 15),
                       overflow: TextOverflow.ellipsis,
                     ),
                   )
                ]),
                const SizedBox(height: 8),
                
                // Audio
                Row(children: [
                   const Icon(Icons.music_note, color: Colors.white70, size: 14), 
                   const SizedBox(width: 4), 
                   Expanded(
                     child: Text(musicDisplay, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis),
                   )
                ]),
                const SizedBox(height: 20),
                
                // Creative Price / Book Button
                GestureDetector(
                  onTap: () async {
                       // Pause video and audio immediately to prevent background playback
                       widget.controller?.pause();
                       widget.audioPlayer?.pause();

                       final hostelId = widget.videoData['hostelId'];
                       DocumentSnapshot? doc;

                       if (hostelId != null) {
                         doc = await FirebaseFirestore.instance.collection('hostels').doc(hostelId).get();
                       } else {
                         final name = widget.videoData['name'];
                         if (name != null) {
                           doc = await firestoreService.findHostelByName(name);
                         }
                       }
                       
                       if (doc != null && doc.exists && context.mounted) {
                         final d = doc.data() as Map<String, dynamic>;
                         d['id'] = doc.id;
                         
                         // Wait for return, then resume
                         await Navigator.push(
                           context, 
                           MaterialPageRoute(
                             builder: (_) => HostelDetailsPage(
                               hostel: d,
                               preSelectedRoomId: widget.videoData['roomId']?.toString(),
                             ),
                           ),
                         );
                         
                         if (context.mounted) {
                           widget.controller?.play();
                           if (!widget.isMuted) widget.audioPlayer?.resume();
                         }
                       } else {
                         if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hostel not found: '${widget.videoData['name'] ?? 'Unknown'}'"), backgroundColor: Colors.redAccent));
                         widget.controller?.play(); // Resume if failed
                       }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E2AB7), Color(0xFF1BFFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF2E2AB7).withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(text: "BOOK NOW  ", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            TextSpan(text: "|  GH₵$priceStr", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          ]
                        ),
                      ),
                    ),
                  ),
                ),
             ],
          ),
        ),

        // 4. Action Layer (Right Side)
        Positioned(
          right: 12,
          bottom: 140,
          child: Column(
            children: [
               _ProfileButton(photoUrl: widget.videoData['agentPhoto']),
               const SizedBox(height: 24),
               // 2. Like Button
               LikeButton(
                 clipId: widget.videoData['id'], 
                 likes: widget.likes,
                 initialCount: widget.videoData['likes'] is int ? widget.videoData['likes'] : null,
               ),
               const SizedBox(height: 24),
               CommentButton(
                  clipId: widget.videoData['id'],
                  initialCount: widget.videoData['commentCount'] ?? 0,
                ),
               const SizedBox(height: 24),
               _ActionBtn(icon: Icons.share_rounded, label: "Share", onTap: () async {
                  final url = widget.videoData['url'] as String?;
                  if (url != null) Share.share("${widget.videoData['name']}\n$url");
               }),
               
               // 5. Delete Button (Conditional)
               if (widget.isAdmin || (FirebaseAuth.instance.currentUser?.uid == widget.videoData['agentId'])) ...[
                  const SizedBox(height: 24),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded, 
                    label: "Delete", 
                    color: Colors.redAccent,
                    onTap: widget.onDelete,
                  ),
               ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatefulWidget {
  final String? photoUrl;
  const _ProfileButton({this.photoUrl});

  @override
  State<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<_ProfileButton> {
  bool _isFollowing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to profile or just toggle follow
        setState(() => _isFollowing = !_isFollowing);
      },
      child: SizedBox(
        height: 60,
        width: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1)
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[800],
                backgroundImage: (widget.photoUrl != null && widget.photoUrl!.trim().isNotEmpty) 
                    ? NetworkImage(widget.photoUrl!.trim()) 
                    : null,
                child: (widget.photoUrl == null || widget.photoUrl!.trim().isEmpty) 
                    ? const Icon(Icons.person, color: Colors.white) 
                    : null,
              ),
            ),
            if (!_isFollowing)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF2E63), // TikTok Red/Pink
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 14),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class LikeButton extends StatefulWidget {
  final String clipId;
  final List<dynamic> likes;
  final int? initialCount;

  const LikeButton({super.key, required this.clipId, required this.likes, this.initialCount});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isLiked = false;
  int _count = 0;
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    _isLiked = uid != null && widget.likes.contains(uid);
    _count = widget.initialCount ?? widget.likes.length;

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login to like")));
      return;
    }

    _controller.forward().then((_) => _controller.reverse());
    
    setState(() {
      _isLiked = !_isLiked;
      _count += _isLiked ? 1 : -1;
    });

    try {
      await _firestoreService.toggleClipLike(user.uid, widget.clipId, _isLiked);
    } catch (e) {
      debugPrint("Like error: $e");
      // Revert if error (optional)
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3), 
                shape: BoxShape.circle
              ),
              child: Icon(
                Icons.favorite, 
                color: _isLiked ? const Color(0xFFFF2E63) : Colors.white, 
                size: 32
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text("$_count", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }
}

class CommentButton extends StatelessWidget {
  final String clipId;
  final int initialCount;

  const CommentButton({super.key, required this.clipId, required this.initialCount});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getClip(clipId),
      builder: (context, snapshot) {
        int count = initialCount;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          count = data['commentCount'] ?? 0;
        }

        return _ActionBtn(
          icon: Icons.comment_rounded, 
          label: "$count", 
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _CommentsSheet(clipId: clipId),
            );
          }
        );
      },
    );
  }
}


class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
       onTap: onTap,
       child: Column(
         children: [
           Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
             child: Icon(icon, color: color, size: 30),
           ),
           const SizedBox(height: 6),
           Text(label, style: TextStyle(color: color == Colors.white ? Colors.white : color, fontSize: 13, fontWeight: FontWeight.bold))
         ],
       ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String clipId;
  const _CommentsSheet({required this.clipId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _firestoreService = FirestoreService();

  void _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
    String name = "User";
    String? photo;
    try {
      final uDoc = await _firestoreService.getUserProfile(user.uid).first;
      if (uDoc.exists) {
         final d = uDoc.data() as Map<String, dynamic>;
         name = d['name'] ?? "User";
         photo = d['photoUrl'];
      }
    } catch (_) {}
    await _firestoreService.addClipComment(user.uid, widget.clipId, text, name, photo);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9,
      builder: (_, scrollController) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121212) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Grab Handle
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Comments", 
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87
                      )
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey : Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getClipComments(widget.clipId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No comments yet", 
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                        )
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                         final d = docs[index].data() as Map<String, dynamic>;
                         return ListTile(
                           leading: CircleAvatar(
                             backgroundImage: d['userPhoto'] != null ? NetworkImage(d['userPhoto']) : null,
                             child: d['userPhoto'] == null ? const Icon(Icons.person) : null,
                           ),
                           title: Text(
                             d['userName'] ?? "User", 
                             style: TextStyle(
                               fontWeight: FontWeight.bold, 
                               fontSize: 13,
                               color: isDark ? Colors.white : Colors.black87,
                             )
                           ),
                           subtitle: Text(
                             d['text'] ?? "",
                             style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                           ),
                         );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: _post,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}


