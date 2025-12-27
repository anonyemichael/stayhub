import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:share_plus/share_plus.dart';

class ClipsPage extends StatefulWidget {
  final bool isActive;
  const ClipsPage({super.key, this.isActive = true});

  @override
  State<ClipsPage> createState() => _ClipsPageState();
}

class _ClipsPageState extends State<ClipsPage> with WidgetsBindingObserver {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isAppActive = true;
  
  // Cache for controllers: Key = Index, Value = Controller
  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _initializedIndices = {};

  final FirestoreService _firestoreService = FirestoreService();
  List<QueryDocumentSnapshot> _clips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _loadClips();
  }

  Future<void> _loadClips() async {
    final snapshot = await _firestoreService.getClips().first;
    if (mounted) {
       setState(() {
         _clips = snapshot.docs;
         _isLoading = false;
       });
       if (_clips.isNotEmpty) {
         _onPageChanged(0); 
       }
    }
  }

  /*
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  */

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    // Safely dispose controllers
    try {
      for (var controller in _controllers.values) {
        controller.dispose();
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
        _playCurrent();
      } else {
        _pauseCurrent();
      }
    }
  }

  void _playCurrent() {
    if (!mounted) return;
    // Only play if active and controller exists
    if (widget.isActive && _isAppActive && _controllers.containsKey(_currentIndex)) {
      final controller = _controllers[_currentIndex];
      if (controller != null && controller.value.isInitialized) {
         controller.play();
      }
    }
  }

  void _pauseCurrent() {
    if (_controllers.containsKey(_currentIndex)) {
      _controllers[_currentIndex]?.pause();
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      _controllers[_currentIndex]?.pause();
      _controllers[_currentIndex]?.seekTo(Duration.zero);
    }

    _currentIndex = index;
    _playCurrent();

    // Garbage Collection: Keep only [index-1, index, index+1]
    final keysToRemove = <int>[];
    _controllers.forEach((key, controller) {
      if (key < index - 1 || key > index + 1) {
        keysToRemove.add(key);
      }
    });

    for (var key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
      _initializedIndices.remove(key);
    }

    // Pre-load logic
    _initControllerAtIndex(index);     
    _initControllerAtIndex(index + 1); 
    _initControllerAtIndex(index - 1); 
  }

  Future<void> _initControllerAtIndex(int index) async {
    if (index < 0 || index >= _clips.length) return;
    if (_controllers.containsKey(index)) return;

    final url = (_clips[index].data() as Map<String, dynamic>)['url'] as String?;
    if (url == null) return;

    VideoPlayerController controller;
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      if (fileInfo != null) {
        controller = VideoPlayerController.file(fileInfo.file);
      } else {
         controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      _controllers[index] = controller; 

      await controller.initialize();
      await controller.setLooping(true);
      
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
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
        itemCount: _clips.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final data = _clips[index].data() as Map<String, dynamic>;
          data['id'] = _clips[index].id;
          
          final controller = _controllers[index];
          final isInitialized = _initializedIndices.contains(index);

          return VideoPlayerItem(
             key: ValueKey("video_$index"), 
             videoData: data,
             controller: controller, 
             isInitialized: isInitialized,
          );
        },
      ),
    );
  }
}

class VideoPlayerItem extends StatelessWidget {
  final Map<String, dynamic> videoData;
  final VideoPlayerController? controller;
  final bool isInitialized;

  const VideoPlayerItem({
    super.key, 
    required this.videoData, 
    required this.controller, 
    required this.isInitialized
  });

  @override
  Widget build(BuildContext context) {
    const musicMap = {
      'original': 'Original Audio',
      'lofi': 'Relaxing Lo-Fi',
      'pop': 'Upbeat Pop',
      'afrobeat': 'Afrobeat Vibes',
    };
    final musicName = musicMap[videoData['music']] ?? 'Original Audio';
    final firestoreService = FirestoreService();

    // Safe parsing for price
    final priceRaw = videoData['price'];
    final String priceStr = (priceRaw?.toString() ?? '0').replaceAllMapped(
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
             child: (isInitialized && controller != null)
                 ? GestureDetector(
                     onTap: () {
                        if (controller!.value.isPlaying) {
                           controller!.pause(); 
                        } else {
                           controller!.play();
                        }
                     },
                     child: SizedBox.expand(
                       child: FittedBox(
                         fit: BoxFit.cover,
                         child: SizedBox(
                           width: controller!.value.size.width,
                           height: controller!.value.size.height,
                           child: VideoPlayer(controller!),
                         ),
                       ),
                     ),
                   )
                 : const CircularProgressIndicator(color: Colors.white),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text("${videoData['capacity'] ?? 4} in a room", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("${videoData['rating'] ?? 4.5} ★", style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Name
                Text(
                  videoData['name'] ?? "Hostel Tour",
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
                     child: Text(videoData['location'] ?? "Unknown Location", 
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
                   Text(musicName, style: const TextStyle(color: Colors.white70, fontSize: 13))
                ]),
                const SizedBox(height: 20),
                
                // Creative Price / Book Button
                GestureDetector(
                  onTap: () async {
                       // Pause video immediately to prevent background playback
                       controller?.pause();

                       final loc = videoData['location'];
                       if (loc == null) {
                         controller?.play();
                         return; 
                       }
                       
                       final doc = await firestoreService.findHostelByName(loc);
                       if (doc != null && context.mounted) {
                         final d = doc.data() as Map<String, dynamic>;
                         d['id'] = doc.id;
                         
                         // Wait for return, then resume
                         await Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: d)));
                         
                         if (context.mounted) controller?.play();
                       } else {
                         if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hostel details not found")));
                         controller?.play(); // Resume if failed
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
                        BoxShadow(color: const Color(0xFF2E2AB7).withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))
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
               _ProfileButton(photoUrl: videoData['agentPhoto']),
               const SizedBox(height: 24),
               LikeButton(
                 clipId: videoData['id'], 
                 likes: List.from(videoData['likes'] ?? [])
               ),
               const SizedBox(height: 24),
               _ActionBtn(
                 icon: Icons.comment_rounded, 
                 label: "${videoData['commentCount'] ?? 0}", 
                 onTap: () {
                    showModalBottomSheet(
                       context: context,
                       backgroundColor: Colors.transparent,
                       isScrollControlled: true,
                       builder: (_) => _CommentsSheet(clipId: videoData['id']),
                    );
                 }
               ),
               const SizedBox(height: 24),
               _ActionBtn(icon: Icons.share_rounded, label: "Share", onTap: () async {
                  final url = videoData['url'] as String?;
                  if (url != null) Share.share("${videoData['name']}\n$url");
               }),
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
                backgroundImage: widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                child: widget.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
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

  const LikeButton({super.key, required this.clipId, required this.likes});

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
    _count = widget.likes.length;

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
                color: Colors.black.withValues(alpha: 0.3), 
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
             decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
             child: Icon(icon, color: color, size: 30),
           ),
           const SizedBox(height: 6),
           Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
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
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getClipComments(widget.clipId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text("No comments yet"));
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
                           title: Text(d['userName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                           subtitle: Text(d['text'] ?? ""),
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
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          filled: true,
                          fillColor: Colors.grey[100],
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
