import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';

class ClipsPage extends StatelessWidget {
  const ClipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getClips(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong', style: TextStyle(color: Colors.white)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off, color: Colors.white54, size: 50),
                  SizedBox(height: 10),
                  Text('No clips available.', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          final videoDocs = snapshot.data!.docs;

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videoDocs.length,
            itemBuilder: (context, index) {
              final doc = videoDocs[index];
              final videoData = doc.data() as Map<String, dynamic>;
              // Inject ID for updates
              final dataWithId = Map<String, dynamic>.from(videoData);
              dataWithId['id'] = doc.id;
              return VideoPlayerWidget(video: dataWithId);
            },
          );
        },
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final Map<String, dynamic> video;

  const VideoPlayerWidget({super.key, required this.video});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isPlaying = true;
  bool _showPauseIcon = false;
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    final videoUrl = widget.video['url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading video: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
      _showPauseIcon = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  // --- ACTIONS ---

  Future<void> _toggleLike() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login to like clips")));
      return;
    }
    
    final likes = List<String>.from(widget.video['likes'] ?? []);
    final isLiked = likes.contains(user.uid);
    final clipId = widget.video['id'];

    if (clipId != null) {
      await _firestoreService.toggleClipLike(user.uid, clipId, isLiked);
    }
  }

  void _showComments() {
    final clipId = widget.video['id'];
    if (clipId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CommentsBottomSheet(clipId: clipId),
    );
  }

  Future<void> _bookNow() async {
    final location = widget.video['location'] as String?;
    if (location == null) return;

    // Try to find the hostel by name/location
    // In a real app, 'hostelId' should be on the clip document.
    // Here we try to find it by matching the 'location' field which in our seeder matches the hostel name sometimes.
    // Actually, seeder puts 'location': 'Sunshine Residency' which is the NAME of the hostel.
    
    final doc = await _firestoreService.findHostelByName(location);
    
    if (doc != null && mounted) {
      final hostelData = doc.data() as Map<String, dynamic>;
      hostelData['id'] = doc.id;
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: hostelData)),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hostel details not found")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.video['name'] ?? 'Hostel Tour';
    final location = widget.video['location'] ?? 'Unknown Location';
    final rating = widget.video['rating']?.toString() ?? '4.5';
    final price = widget.video['price']?.toString() ?? '0';
    
    final likes = List.from(widget.video['likes'] ?? []);
    final user = _auth.currentUser;
    final isLiked = user != null && likes.contains(user.uid);
    final likeCount = widget.video['likeCount'] ?? 0;
    final commentCount = widget.video['commentCount'] ?? 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: Colors.black,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white54))
                : (_controller != null && _controller!.value.isInitialized)
                ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            )
                : const Center(child: Text("Failed to load video", style: TextStyle(color: Colors.white))),
          ),
        ),

        if (!_isLoading)
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showPauseIcon ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: Icon(
                  _isPlaying ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
          ),

        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  stops: [0.6, 1.0],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionBtn(
                isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart, 
                "$likeCount", 
                isLiked ? Colors.redAccent : Colors.white,
                onTap: _toggleLike
              ),
              const SizedBox(height: 20),
              _buildActionBtn(
                FontAwesomeIcons.solidCommentDots, 
                "$commentCount", 
                Colors.white,
                onTap: _showComments
              ),
              const SizedBox(height: 20),
              // REMOVED SHARE BUTTON
            ],
          ),
        ),

        Positioned(
          left: 16,
          bottom: 110,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text("$rating Rating", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _bookNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                      child: Text(
                          "Book from $price",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CommentsBottomSheet extends StatefulWidget {
  final String clipId;
  const _CommentsBottomSheet({required this.clipId});

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final _commentController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  void _postComment() async {
    final text = _commentController.text.trim();
    final user = _auth.currentUser;
    if (text.isEmpty || user == null) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    // Fetch minimal user details for the comment
    // Ideally stored in Auth user profile or fetched once
    String name = "User";
    String? photo;
    
    try {
      final userDoc = await _firestoreService.getUserProfile(user.uid).first;
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        name = data['name'] ?? "User";
        photo = data['photoUrl'];
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }

    await _firestoreService.addClipComment(user.uid, widget.clipId, text, name, photo);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 10),
              const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getClipComments(widget.clipId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No comments yet. Be the first!"));
                    }
                    return ListView.builder(
                      controller: controller,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: data['userPhoto'] != null ? NetworkImage(data['userPhoto']) : null,
                            child: data['userPhoto'] == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(data['userName'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(data['text'] ?? ""),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                  left: 16,
                  right: 16,
                  top: 10
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: _postComment,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
