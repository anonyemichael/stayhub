import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';

class AdminManageAdminsView extends StatefulWidget {
  const AdminManageAdminsView({super.key});

  @override
  State<AdminManageAdminsView> createState() => _AdminManageAdminsViewState();
}

class _AdminManageAdminsViewState extends State<AdminManageAdminsView> {
  final _emailController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Manage Administrators", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('admins').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
             return Center(child: Text("No admins found.", style: TextStyle(color: textColor)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final email = data['email'] ?? 'Unknown';
              final role = data['role'] ?? 'content_admin';
              final isSuper = role == 'super_admin';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  border: isSuper ? Border.all(color: Colors.amber.withOpacity(0.5)) : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isSuper ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                      child: Icon(isSuper ? Icons.verified_user : Icons.admin_panel_settings, color: isSuper ? Colors.amber : Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isSuper ? Colors.amber : Colors.blue).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4)
                            ),
                            child: Text(isSuper ? "Super Admin" : "Content Admin", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSuper ? Colors.amber[800] : Colors.blue[800])),
                          )
                        ],
                      ),
                    ),
                    if (!isSuper) // Cannot remove other super admins easily here (safety)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmRemove(email),
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdminDialog,
        backgroundColor: Colors.blue[900],
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Invite Admin", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showAddAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite Administrator"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the email of the user you want to promote to Content Admin.\n\nThey must sign up with this email to access the panel."),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addAdmin();
            },
            child: const Text("Send Invite"),
          ),
        ],
      ),
    );
  }

  Future<void> _addAdmin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    
    // Defaulting to Content Admin as requested
    await _firestoreService.addAdmin(
      email, 
      'content_admin', 
      FirebaseAuth.instance.currentUser?.email ?? 'system'
    );
    
    _emailController.clear();
    setState(() => _isLoading = false);
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Admin Added Successfully!")));
    }
  }

  Future<void> _confirmRemove(String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove Admin?"),
        content: Text("Are you sure you want to remove $email? They will lose access immediately."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.removeAdmin(email);
    }
  }
}
