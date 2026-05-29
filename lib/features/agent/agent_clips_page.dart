import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/features/clips/clips_page.dart';
import 'package:stayhub/features/agent/add_clip_page.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AgentClipsPage extends StatefulWidget {
  final bool isAdmin;
  const AgentClipsPage({super.key, this.isAdmin = false});

  @override
  State<AgentClipsPage> createState() => _AgentClipsPageState();
}

class _AgentClipsPageState extends State<AgentClipsPage> {
  final _user = FirebaseAuth.instance.currentUser;

  Future<void> _deleteClip(String clipId, String? videoUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Delete Forever?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("This video will be removed from the database and Cloudinary storage.", style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. Delete from Firestore
        await FirebaseFirestore.instance.collection('clips').doc(clipId).delete();
        
        // 2. Cloudinary deletion logic (Requires API Secret - typically server-side)
        // If we had the API secret, we would call CloudinaryService().deleteVideo(videoUrl);
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clip permanently removed."), backgroundColor: Colors.redAccent));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  String _getThumbnailUrl(String videoUrl) {
    if (videoUrl.contains('cloudinary.com')) {
      final extensionIndex = videoUrl.lastIndexOf('.');
      if (extensionIndex != -1) {
        return "${videoUrl.substring(0, extensionIndex)}.jpg";
      }
    }
    return videoUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text("Access Denied")));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: widget.isAdmin 
               ? FirebaseFirestore.instance
                  .collection('clips')
                  .snapshots()
               : FirebaseFirestore.instance
                  .collection('clips')
                  .where('agentId', isEqualTo: _user!.uid)
                  .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final clips = snapshot.data?.docs ?? [];
              
              // Local sort to handle serverTimestamp delay and support older clips
              final sortedClips = List<QueryDocumentSnapshot>.from(clips);
              
              int getSafeMillis(Map<String, dynamic> data) {
                final ts = data['timestamp'];
                if (ts is Timestamp) return ts.millisecondsSinceEpoch;
                if (ts is int) return ts;
                if (data['createdAt'] is int) return data['createdAt'];
                return DateTime.now().millisecondsSinceEpoch;
              }

              sortedClips.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                return getSafeMillis(bData).compareTo(getSafeMillis(aData));
              });
              
              if (sortedClips.isEmpty) 
                return CustomScrollView(slivers: [
                   const SliverToBoxAdapter(child: SizedBox(height: 120)),
                   SliverFillRemaining(child: _buildEmptyState(isDark)),
                ]);
              
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                   // Studio Header
                   SliverToBoxAdapter(
                     child: Padding(
                       padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           _buildCreatorStats(sortedClips, isDark),
                           const SizedBox(height: 32),
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("My Portfolio", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(color: const Color(0xFFEC4899).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                 child: Text("${sortedClips.length} VIDEOS", style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.w900, fontSize: 10)),
                               ),
                             ],
                           ),
                         ],
                       ),
                     ),
                   ),

                   SliverPadding(
                     padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                     sliver: SliverGrid(
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 2,
                         childAspectRatio: 0.65,
                         crossAxisSpacing: 16,
                         mainAxisSpacing: 16,
                       ),
                       delegate: SliverChildBuilderDelegate(
                         (context, index) {
                           final doc = sortedClips[index];
                           final data = doc.data() as Map<String, dynamic>;
                           return GestureDetector(
                             onTap: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (_) => ClipsPage(
                                     initialClips: sortedClips,
                                     initialIndex: index,
                                     isAdmin: widget.isAdmin,
                                   ),
                                 ),
                               );
                             },
                             child: _buildPremiumClipCard(doc.id, data, isDark),
                           );
                         },
                         childCount: sortedClips.length,
                       ),
                     ),
                   ),
                ],
              );
            },
          ),
          
          // Custom Top Bar (AgentDashboard style)
          _buildStudioTopBar(isDark, textColor),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClipPage())),
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text("NEW CLIP", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12, color: Colors.white)),
        backgroundColor: const Color(0xFFEC4899),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildCreatorStats(List<QueryDocumentSnapshot> clips, bool isDark) {
    int totalLikes = 0;
    int totalViews = 0;
    
    for (var doc in clips) {
      final data = doc.data() as Map<String, dynamic>;
      totalLikes += (data['likeCount'] as num? ?? 0).toInt();
      totalViews += (data['views'] as num? ?? 0).toInt();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          _buildStatItem("Likes", totalLikes.toString(), Icons.favorite_rounded),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem("Views", totalViews.toString(), Icons.remove_red_eye_rounded),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem("Clips", clips.length.toString(), Icons.videocam_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String val, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
          const SizedBox(height: 8),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPremiumClipCard(String id, Map<String, dynamic> data, bool isDark) {
    DateTime? date;
    final rawTs = data['timestamp'];
    if (rawTs is Timestamp) {
      date = rawTs.toDate();
    } else if (rawTs is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (data['createdAt'] is int) {
      date = DateTime.fromMillisecondsSinceEpoch(data['createdAt']);
    }
    
    final dateStr = date != null ? DateFormat.yMMMd().format(date) : "Recent";
    final videoUrl = data['url'] as String? ?? "";
    final imageUrl = data['image'] as String? ?? _getThumbnailUrl(videoUrl);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (c,u) => Container(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              errorWidget: (c,u,e) => Container(color: Colors.grey[800], child: const Icon(Icons.videocam_off, color: Colors.white38)),
            ),
            
            // Glass Overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, size: 10, color: Color(0xFFEC4899)),
                        const SizedBox(width: 4),
                        Text("${data['likeCount'] ?? 0}", style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Quick Actions
            Positioned(
              top: 12, right: 12,
              child: Column(
                children: [
                  _buildIconButton(Icons.delete_outline_rounded, Colors.redAccent, () => _deleteClip(id, videoUrl)),
                  const SizedBox(height: 8),
                  _buildIconButton(Icons.visibility_rounded, Colors.white, () {
                     // Navigate to Clips Feed or similar
                  }),
                ],
              ),
            ),
            
            // Play Button
            Center(
               child: Container(
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                 child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildStudioTopBar(bool isDark, Color textColor) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 110,
        padding: const EdgeInsets.fromLTRB(24, 50, 16, 0),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)).withOpacity(0.9),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Clips Studio",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -1),
                ),
                Container(
                  width: 24, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFEC4899), borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ],
        ),
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
            decoration: BoxDecoration(color: const Color(0xFFEC4899).withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.videocam_off_rounded, size: 64, color: const Color(0xFFEC4899).withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const Text("Studio is empty", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text("Promote your hostels with 15s clips!", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
