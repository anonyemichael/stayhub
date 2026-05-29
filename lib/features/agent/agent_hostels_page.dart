import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/agent/add_hostel_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AgentHostelsPage extends StatefulWidget {
  const AgentHostelsPage({super.key});

  @override
  State<AgentHostelsPage> createState() => _AgentHostelsPageState();
}

class _AgentHostelsPageState extends State<AgentHostelsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final firestoreService = FirestoreService();
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please log in"));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const SizedBox(height: 110), // Offset for the Modern Top Bar in AgentDashboard
          _buildFilterBar(isDark),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('hostels').where('agentId', isEqualTo: user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final allDocs = snapshot.data!.docs;
                final docs = _activeFilter == 'All' 
                    ? allDocs 
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final rooms = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
                        int totalSlots = 0;
                        if (rooms.isNotEmpty) {
                          for (var r in rooms) totalSlots += (r['available'] as num? ?? 0).toInt();
                        } else {
                          totalSlots = int.tryParse(data['capacity']?.toString() ?? '0') ?? 0;
                        }
                        final bool isFull = (data['isFull'] == true) || totalSlots <= 0;
                        final status = isFull ? 'Full' : 'Active';
                        return status == _activeFilter;
                      }).toList();

                if (docs.isEmpty) return _buildEmptyState(isDark);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildPremiumPropertyCard(context, data, docs[index].id, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHostelPage())),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_home_rounded, color: Colors.white),
        label: const Text("LIST PROPERTY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['All', 'Active', 'Full'].map((filter) {
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(filter, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
              selected: isSelected,
              onSelected: (val) => setState(() => _activeFilter = filter),
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPremiumPropertyCard(BuildContext context, Map<String, dynamic> data, String id, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final rooms = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
    int totalSlots = 0;
    if (rooms.isNotEmpty) {
      for (var r in rooms) totalSlots += (r['available'] as num? ?? 0).toInt();
    } else {
      totalSlots = int.tryParse(data['capacity']?.toString() ?? '0') ?? 0;
    }
    final isFull = (data['isFull'] == true) || totalSlots <= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: data['image'] ?? '',
                height: 200, width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              Positioned(
                top: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFull ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isFull ? "FULL" : "ACTIVE",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                  ),
                ),
              ),
              Positioned(
                top: 16, left: 16,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context, id, data['name'] ?? 'this property'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(data['name'] ?? 'Property', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    ),
                    _buildStartingPrice(data),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(data['school'] ?? 'Main Campus', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildIconButton(Icons.edit_note_rounded, "Edit", Colors.blue, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddHostelPage(hostelId: id, initialData: data)));
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildIconButton(
                        isFull ? Icons.check_circle_outline_rounded : Icons.block_flipped, 
                        isFull ? "Activate" : "Mark Full", 
                        isFull ? Colors.green : Colors.orange, 
                        () async {
                          await FirebaseFirestore.instance.collection('hostels').doc(id).update({'isFull': !isFull});
                        }
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildIconButton(
                        Icons.delete_outline_rounded, 
                        "Delete", 
                        Colors.redAccent, 
                        () => _confirmDelete(context, id, data['name'] ?? 'this property')
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Property?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete '$name'? This action cannot be undone and will remove all associated clips and data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await firestoreService.deleteHostelCascade(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Property deleted successfully"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting property: $e"), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartingPrice(Map<String, dynamic> data) {
    final rooms = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
    double minPrice = 0;
    if (rooms.isNotEmpty) {
      final prices = rooms.map((r) => ((r['price'] as num? ?? 0).toDouble() * 1.10)).toList();
      prices.sort();
      minPrice = prices.first;
    } else {
      final base = (data['price'] is num) ? (data['price'] as num).toDouble() : (double.tryParse(data['price']?.toString() ?? '0') ?? 0.0);
      minPrice = base * 1.10;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text("STUDENT PRICE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
        Text("GHS ${minPrice.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 18)),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work_outlined, size: 80, color: isDark ? Colors.white12 : Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("No properties listed yet.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}