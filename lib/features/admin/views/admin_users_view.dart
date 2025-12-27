import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/features/admin/admin_create_agent.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
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
        title: Text("User Management", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: "Agents"),
            Tab(text: "Students"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UserList(collection: 'agents', isAgent: true),
          _UserList(collection: 'users', isAgent: false),
        ],
      ),
      floatingActionButton: _tabController.index == 0 
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCreateAgentPage()));
            },
            backgroundColor: Colors.black, // Matching the "God Mode" theme
            icon: const Icon(Icons.person_add, color: Colors.greenAccent),
            label: const Text("New Agent", style: TextStyle(color: Colors.greenAccent)),
          )
        : null,
    );
  }
}

class _UserList extends StatelessWidget {
  final String collection;
  final bool isAgent;

  const _UserList({required this.collection, required this.isAgent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("No users found", style: TextStyle(color: Colors.grey[600])));

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final isVerified = data['isVerified'] == true;
            final isBlocked = data['isBlocked'] == true;
            final name = data['name'] ?? (isAgent ? 'Unnamed Agent' : 'Unnamed Student');
            final email = data['email'] ?? 'No Email';
            final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isAgent 
                            ? [Colors.orangeAccent, Colors.deepOrange] 
                            : [Colors.blueAccent, Colors.lightBlueAccent],
                        begin: Alignment.topLeft, end: Alignment.bottomRight
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                  ),
                  const SizedBox(width: 16),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                           children: [
                             Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                             if (isVerified) ...[
                               const SizedBox(width: 6),
                               const Icon(Icons.verified, color: Colors.blueAccent, size: 16)
                             ]
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                         const SizedBox(height: 8),
                         // Status Chips
                         Row(
                           children: [
                             if (isBlocked)
                               _StatusChip(text: "Blocked", color: Colors.red, isDark: isDark)
                             else if (isVerified && isAgent)
                               _StatusChip(text: "Verified", color: Colors.green, isDark: isDark)
                             else
                               _StatusChip(text: isAgent ? "Pending" : "Active", color: Colors.grey, isDark: isDark),
                           ],
                         )
                      ],
                    ),
                  ),

                  // Actions
                  Column(
                    children: [
                      if (isAgent && !isVerified)
                         IconButton(
                           icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                           tooltip: "Verify Agent",
                           onPressed: () => _verifyAgent(context, id),
                         ),
                      IconButton(
                         icon: Icon(isBlocked ? Icons.lock_open : Icons.block, color: isBlocked ? Colors.green : Colors.redAccent),
                         tooltip: isBlocked ? "Unblock" : "Block User",
                         onPressed: () => _toggleBlock(context, collection, id, !isBlocked),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _verifyAgent(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('agents').doc(docId).update({'isVerified': true});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agent Verified!")));
  }

  Future<void> _toggleBlock(BuildContext context, String collection, String docId, bool shouldBlock) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).update({'isBlocked': shouldBlock});
    final action = shouldBlock ? "Blocked" : "Unblocked";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User $action!")));
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;
  
  const _StatusChip({required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
