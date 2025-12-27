import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:stayhub/features/agent/add_hostel_page.dart';
import 'package:stayhub/features/agent/add_clip_page.dart';

class AdminHostelsView extends StatefulWidget {
  const AdminHostelsView({super.key});

  @override
  State<AdminHostelsView> createState() => _AdminHostelsViewState();
}

class _AdminHostelsViewState extends State<AdminHostelsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
       // Rebuild to show/hide FAB based on tab index
       if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Hostel Management", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Active"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _HostelList(isPending: true),
          _HostelList(isPending: false),
        ],
      ),
      floatingActionButton: _tabController.index == 1 
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: "btn_clip",
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClipPage()));
                },
                icon: const Icon(Icons.video_call),
                label: const Text("Post Clip"),
                backgroundColor: Colors.purpleAccent,
              ),
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: "btn_hostel",
                onPressed: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHostelPage()));
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Hostel"),
                backgroundColor: Colors.blueAccent,
              ),
            ],
          )
        : null,
    );
  }
}

class _HostelList extends StatelessWidget {
  final bool isPending;
  const _HostelList({required this.isPending});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // If pending, look for status 'pending' (or null for legacy), else 'approved'
      stream: FirebaseFirestore.instance.collection('hostels').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          return isPending ? status == 'pending' : status == 'approved';
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isPending ? Icons.pending_actions_rounded : Icons.apartment_rounded, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(isPending ? "No pending approvals" : "No active hostels", style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 20, bottom: 100, left: 20, right: 20),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
             final data = docs[index].data() as Map<String, dynamic>;
             final imageUrl = data['image'] ?? '';
             final name = data['name'] ?? 'Unnamed';
             final location = data['location'] ?? 'No location';
             final price = data['price'] ?? '0';

             return Container(
               decoration: BoxDecoration(
                 color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                 borderRadius: BorderRadius.circular(24),
                 boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))
                 ],
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // Image Section
                   Stack(
                     children: [
                       ClipRRect(
                         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                         child: CachedNetworkImage(
                           imageUrl: imageUrl, 
                           height: 180,
                           width: double.infinity,
                           fit: BoxFit.cover,
                           placeholder: (c,u) => Container(color: Colors.grey[200]),
                           errorWidget: (c,u,e) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 40)),
                         ),
                       ),
                       Positioned(
                         top: 12,
                         right: 12,
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                           decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                           child: Text("GHS $price", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                         ),
                       )
                     ],
                   ),
                   
                   // Info Section
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(name, 
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3436))
                         ),
                         const SizedBox(height: 4),
                         Row(children: [
                           Icon(Icons.location_on_rounded, color: Colors.grey[500], size: 14),
                           const SizedBox(width: 4),
                           Expanded(
                             child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 13))
                           ),
                         ]),
                         const SizedBox(height: 16),
                         // Actions
                         Row(
                           children: [
                             if (isPending)
                               Expanded(
                                 child: _ActionButton(
                                   label: "Approve",
                                   icon: Icons.check_rounded, 
                                   color: Colors.green, 
                                   isFilled: true,
                                   onTap: () => _approveHostel(context, docs[index].id)
                                 ),
                               ),
                             if (isPending) const SizedBox(width: 12),
                             Expanded(
                               child: _ActionButton(
                                 label: "Delete",
                                 icon: Icons.delete_outline_rounded, 
                                 color: Colors.redAccent, 
                                 isFilled: false,
                                 onTap: () => _deleteHostel(context, docs[index].id)
                               ),
                             ),
                           ],
                         )
                       ],
                     ),
                   )
                 ],
               ),
             );
          },
        );
      },
    );
  }

  Future<void> _approveHostel(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('hostels').doc(docId).update({'status': 'approved'});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hostel Approved!")));
  }

  Future<void> _deleteHostel(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Property?"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('hostels').doc(docId).delete();
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isFilled;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.isFilled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isFilled ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: isFilled ? null : Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isFilled ? Colors.white : color, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isFilled ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      ),
    );
  }
}
