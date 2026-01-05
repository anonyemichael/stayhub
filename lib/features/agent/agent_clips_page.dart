import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/features/clips/clips_page.dart';
import 'package:stayhub/features/agent/add_clip_page.dart';
import 'package:intl/intl.dart';

class AgentClipsPage extends StatefulWidget {
  final bool isAdmin;
  const AgentClipsPage({super.key, this.isAdmin = false});

  @override
  State<AgentClipsPage> createState() => _AgentClipsPageState();
}

class _AgentClipsPageState extends State<AgentClipsPage> {
  final _user = FirebaseAuth.instance.currentUser;

  Future<void> _deleteClip(String clipId) async {
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
        await FirebaseFirestore.instance.collection('clips').doc(clipId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clip deleted")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  String _getThumbnailUrl(String videoUrl) {
    // Attempt to convert Cloudinary video URL to image URL
    if (videoUrl.contains('cloudinary.com')) {
      // Replace file extension (e.g., .mp4, .mov) with .jpg
      final extensionIndex = videoUrl.lastIndexOf('.');
      if (extensionIndex != -1) {
        return "${videoUrl.substring(0, extensionIndex)}.jpg";
      }
    }
    return videoUrl; // Fallback, though likely won't work as image
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text("Access Denied")));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? "Manage All Clips" : "My Clips"),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClipPage()));
        },
        label: const Text("Post New Clip"),
        icon: const Icon(Icons.add_a_photo_outlined),
        backgroundColor: Colors.pinkAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: widget.isAdmin 
           ? FirebaseFirestore.instance
              .collection('clips')
              .orderBy('timestamp', descending: true)
              .snapshots()
           : FirebaseFirestore.instance
              .collection('clips')
              .where('agentId', isEqualTo: _user!.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_creation_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No clips posted yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Promote your hostels with short videos!",
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final clips = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 columns
              childAspectRatio: 0.65, // Taller aspect ratio for vertical video feel
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: clips.length,
            itemBuilder: (context, index) {
              final doc = clips[index];
              final data = doc.data() as Map<String, dynamic>;
              final date = (data['timestamp'] as Timestamp?)?.toDate();
              final dateStr = date != null ? DateFormat.yMMMd().format(date) : "Recent";
              final videoUrl = data['url'] as String? ?? "";
              final imageUrl = data['image'] as String? ?? _getThumbnailUrl(videoUrl);

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                           return Container(
                             color: Colors.grey[800],
                             child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54)),
                           );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[900],
                             child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                      ),
                      
                      // Gradient Overlay for Text Visibility
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? "Hostel Clip",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.thumb_up, size: 12, color: Colors.white.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${data['likeCount'] ?? 0}",
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Text(
                                    dateStr,
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Delete Button (Top Right)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => _deleteClip(doc.id),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          ),
                        ),
                      ),
                      
                      // Play Indicator (Center)
                      Center(
                         child: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                           child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                         ),
                      ),
                      
                      // Tap to Play
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Optional: Play logic. 
                              // For now, simpler to just let them see the grid. 
                              // Or push to clips page?
                              // Pushing to ClipsPage is tricky as it's a feed.
                            },
                          ),
                        ),
                      ),
                      
                      // Explicit hit test for Delete button is higher in stack, so it works.
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
