import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:stayhub/features/admin/admin_create_agent.dart';

class AdminUsersView extends StatefulWidget {
  final bool isSuper;
  const AdminUsersView({super.key, this.isSuper = false}); // Default false if not passed

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    // Allow Super Admins to see all 3 tabs, others see 2.
    _tabController = TabController(length: widget.isSuper ? 3 : 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("User Management", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<List<int>>(
        // Fetch counts for all collections to show them in tabs
        stream: Stream.periodic(const Duration(seconds: 10)).asyncMap((_) async {
          final users = await FirebaseFirestore.instance.collection('users').count().get();
          final agents = await FirebaseFirestore.instance.collection('agents').count().get();
          final admins = await FirebaseFirestore.instance.collection('admins').count().get();
          return [users.count ?? 0, agents.count ?? 0, admins.count ?? 0];
        }),
        initialData: const [0, 0, 0],
        builder: (context, snapshot) {
          final counts = snapshot.data!;
          return Column(
            children: [
                // Tabs Header
                Container(
                  color: bgColor,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blueAccent,
                    tabs: [
                       Tab(text: "Students (${counts[0]})"),
                       Tab(text: "Agents (${counts[1]})"),
                       if (widget.isSuper) Tab(text: "Admins (${counts[2]})"),
                    ]
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Search by name or email...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); }) 
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                        _UserList(collection: 'users', query: _searchQuery, isSuper: widget.isSuper),
                        _UserList(collection: 'agents', query: _searchQuery, isSuper: widget.isSuper),
                        if (widget.isSuper) _UserList(collection: 'admins', query: _searchQuery, isSuper: widget.isSuper),
                    ],
                  ),
                ),
            ],
          );
        }
      ),
      floatingActionButton: _tabController.index == 1 
        ? FloatingActionButton.extended(
            onPressed: _showAddAgentDialog,
            label: const Text("Add New Agent"),
            icon: const Icon(Icons.person_add),
            backgroundColor: Colors.blueAccent,
          )
        : null,
    );
  }

  Future<void> _showAddAgentDialog() async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCreateAgentPage()));
  }
}

class _UserList extends StatefulWidget {
  final String collection;
  final String query;
  final bool isSuper;

  const _UserList({required this.collection, required this.query, required this.isSuper});

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Essential for live updates without flickering when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collection)
          .snapshots(), // Removed orderBy to ensure documents without email field are shown
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.where((doc) {
           final data = doc.data() as Map<String, dynamic>;
           final email = (data['email'] ?? '').toString().toLowerCase();
           final name = (data['name'] ?? '').toString().toLowerCase();
           return email.contains(widget.query) || name.contains(widget.query);
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Text("No users found", style: TextStyle(color: Colors.grey[500])));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: docs.length,
          itemBuilder: (context, index) {
             final data = docs[index].data() as Map<String, dynamic>;
             final id = docs[index].id;
             final name = data['name'] ?? data['email']?.split('@')[0] ?? 'Unknown';
             final email = data['email'] ?? 'No Email';
             final photo = data['photoUrl'];
             final isBanned = data['isBanned'] == true;
             final school = data['school'];
             
             // Role/Status flags
             final isVerified = data['isVerified'] == true;
             final isAgent = widget.collection == 'agents';
             final isAdmin = widget.collection == 'admins';
             final role = data['role'] ?? '';
             final List<String> schoolsOfOperation = List<String>.from(data['schoolsOfOperation'] ?? []);

             return ListTile(
               leading: CircleAvatar(
                 backgroundImage: photo != null ? NetworkImage(photo) : null,
                 backgroundColor: isAdmin ? Colors.amber.withOpacity(0.1) : (isAgent ? Colors.blue.withOpacity(0.1) : null),
                 child: photo == null ? Text(name[0].toUpperCase(), style: TextStyle(color: isAdmin ? Colors.amber[800] : (isAgent ? Colors.blue[800] : null))) : null,
               ),
               title: Row(
                 children: [
                   Expanded(
                     child: Text(name, style: TextStyle(
                         decoration: isBanned ? TextDecoration.lineThrough : null,
                         color: isBanned ? Colors.red : null,
                         fontWeight: FontWeight.bold
                     )),
                   ),
                   if (isAgent && isVerified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16, color: Colors.blue)),
                   if (isAgent && !isVerified) const Padding(padding: EdgeInsets.only(left: 4), child: Text(" (Pending)", style: TextStyle(color: Colors.orange, fontSize: 12))),
                   if (isAdmin) Container(
                     margin: const EdgeInsets.only(left: 8),
                     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                     decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                     child: Text(role == 'super_admin' ? "SUPER" : "ADMIN", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                   ),
                 ],
               ),
               subtitle: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(email),
                    if (isAgent && schoolsOfOperation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: schoolsOfOperation.map((s) => _buildListSchoolBadge(context, s)).toList(),
                      ),
                    ] else if (school != null && school.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildListSchoolBadge(context, school.toString()),
                    ]
                 ],
               ),
               trailing: PopupMenuButton<String>(
                 onSelected: (val) => _handleAction(context, val, id, widget.collection, isBanned),
                 itemBuilder: (context) => [
                     // Promote Student
                     if (widget.collection == 'users')
                        const PopupMenuItem(
                          value: 'promote_agent',
                          child: Row(children: [Icon(Icons.badge, color: Colors.orange), SizedBox(width: 8), Text("Promote (Pending)")]),
                        ),
                     
                     // Approve Agent (Super Only)
                     if (isAgent && !isVerified && widget.isSuper)
                        const PopupMenuItem(
                          value: 'approve_agent',
                          child: Row(children: [Icon(Icons.check_circle, color: Colors.blue), SizedBox(width: 8), Text("Approve Agent")]),
                        ),

                     // Ban/Unban (All Admins)
                     PopupMenuItem(
                       value: 'ban', 
                       child: Row(children: [
                          Icon(isBanned ? Icons.check_circle : Icons.block, color: isBanned ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Text(isBanned ? "Unban User" : "Ban User")
                       ])
                     ),

                     // Delete (Super Only)
                     if (widget.isSuper)
                       const PopupMenuItem(
                         value: 'delete',
                         child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text("Delete Permanently")]),
                       )
                  ],
                ),
              );
           },
         );
       },
     );
   }
 
   Future<void> _handleAction(BuildContext context, String action, String uid, String collection, bool isBanned) async {
       if (action == 'promote_agent') {
          // Promote Logic (With Approval Required)
          final confirm = await showDialog<bool>(
            context: context, 
            builder: (c) => AlertDialog(
               title: const Text("Promote to Agent?"),
               content: const Text("This user will be added to the Agents list but requires Super Admin approval."),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                 TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Promote", style: TextStyle(color: Colors.blue))),
               ],
            )
          );

          if (confirm == true) {
             try {
               final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
               final data = userDoc.data()!;
               
               // Create Agent Profile (Status: Pending)
               await FirebaseFirestore.instance.collection('agents').doc(uid).set({
                 ...data,
                 'role': 'agent',
                 'isVerified': false, // PENDING APPROVAL
                 'balance': 0.0,
                 'hostels': [],
                 'createdAt': FieldValue.serverTimestamp(),
               });

               // NOTE: We do NOT update the 'users' collection role to 'agent'. 
               // This ensures the user retains their 'student' account status.
               // The specific app logic will determine how they access agent features (e.g. separate login or mode switch).

               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Promoted! Waiting for Super Admin approval.")));
             } catch (e) {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error promoting: $e")));
             }
          }

       } else if (action == 'approve_agent') {
          // Verify Logic
          await FirebaseFirestore.instance.collection('agents').doc(uid).update({'isVerified': true});
          // Do NOT update user role to 'agent', keeping them as 'student' in users table.
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Agent Approved & Verified!")));

       } else if (action == 'ban') {
          await FirebaseFirestore.instance.collection(collection).doc(uid).update({
             'isBanned': !isBanned
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBanned ? "User Unbanned" : "User Banned")));
      
       } else if (action == 'delete') {
          if (!widget.isSuper) return; // Guard
          final confirm = await showDialog<bool>(
            context: context, 
            builder: (c) => AlertDialog(
               title: const Text("Delete User?"),
               content: const Text("This cannot be undone."),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                 TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
               ],
            )
          );
          
          if (confirm == true) {
             await FirebaseFirestore.instance.collection(collection).doc(uid).delete();
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Deleted Permanently")));
          }
       }
   }

   Widget _buildListSchoolBadge(BuildContext context, String schoolName) {
     return FutureBuilder<QuerySnapshot>(
       future: FirebaseFirestore.instance.collection('schools').where('name', isEqualTo: schoolName).limit(1).get(),
       builder: (context, snapshot) {
         String? logoUrl;
         if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
           final doc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
           logoUrl = doc['logo_url'];
         }
         
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
           decoration: BoxDecoration(
             color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
             borderRadius: BorderRadius.circular(12),
           ),
           child: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               if (logoUrl != null && logoUrl.isNotEmpty) ...[
                 CircleAvatar(
                   radius: 8,
                   backgroundColor: Colors.white,
                   backgroundImage: NetworkImage(logoUrl),
                 ),
                 const SizedBox(width: 4),
               ] else ...[
                 Icon(Icons.school, size: 10, color: isDark ? Colors.white : Colors.black),
                 const SizedBox(width: 4),
               ],
               Flexible(
                 child: Text(
                   schoolName,
                   overflow: TextOverflow.ellipsis,
                   style: TextStyle(
                     fontSize: 10,
                     fontWeight: FontWeight.bold,
                     color: isDark ? Colors.white : Colors.black,
                   ),
                 ),
               ),
             ],
           ),
         );
       },
     );
   }
}
