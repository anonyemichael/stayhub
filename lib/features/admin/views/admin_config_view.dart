import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminConfigView extends StatefulWidget {
  const AdminConfigView({super.key});

  @override
  State<AdminConfigView> createState() => _AdminConfigViewState();
}

class _AdminConfigViewState extends State<AdminConfigView> {
  final _contactFormKey = GlobalKey<FormState>();
  // final _configService = AppConfigService(); // REMOVED to force direct Firestore usage

  // Controllers for Support Config
  final _whatsappCtrl = TextEditingController(); // Was _adminPhoneCtrl
  final _callCtrl = TextEditingController();    // New
  final _studentEmailCtrl = TextEditingController();
  final _agentHelpEmailCtrl = TextEditingController();
  
  // Controllers for Admin Contact
  final _adminEmailCtrl = TextEditingController(); // Reused for student support email too
  
  // Controllers for Broadcast
  final _broadcastTitleCtrl = TextEditingController();
  final _broadcastBodyCtrl = TextEditingController();
  String _broadcastTarget = 'All Users';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
      final data = doc.data() ?? {};
      
      final studentSupport = data['student_support'] as Map<String, dynamic>? ?? {};
      final agentSupport = data['agent_support'] as Map<String, dynamic>? ?? {};
      final adminContact = data['admin_contact'] as Map<String, dynamic>? ?? {};

      // Load Values or Defaults
      _whatsappCtrl.text = studentSupport['whatsapp'] ?? '233509483401';
      _callCtrl.text = adminContact['phone'] ?? '233533311532';
      
      _adminEmailCtrl.text = studentSupport['email'] ?? adminContact['email'] ?? 'support@stayhubgh.com';
      _agentHelpEmailCtrl.text = agentSupport['email'] ?? 'support@stayhubgh.com';

    } catch (e) {
      debugPrint("Error loading config: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _sanitizePhone(String original) {
    String p = original.trim();
    if (p.startsWith('0')) return '233${p.substring(1)}';
    if (p.startsWith('+')) return p.substring(1);
    return p;
  }

  Future<void> _saveConfig() async {
    if (!_contactFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    String whatsapp = _sanitizePhone(_whatsappCtrl.text);
    String call = _sanitizePhone(_callCtrl.text);

    try {
      await FirebaseFirestore.instance.collection('config').doc('app_config').set({
        // 1. Universal Student Support
        'student_support': {
          'whatsapp': whatsapp,
          'email': _adminEmailCtrl.text.trim(),
        },
        // 2. Agent Support
        'agent_support': {
          'email': _agentHelpEmailCtrl.text.trim(),
        },
        // 3. Admin Contact (Calls Fallback)
        'admin_contact': {
          'phone': call,
          'email': _adminEmailCtrl.text.trim(),
        }
      }, SetOptions(merge: true));
      
      _whatsappCtrl.text = whatsapp;
      _callCtrl.text = call;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Configuration Saved!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // ... _sendBroadcast REMAINED SAME ...
  Future<void> _sendBroadcast() async {
    if (_broadcastTitleCtrl.text.isEmpty || _broadcastBodyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Message required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _broadcastTitleCtrl.text.trim(),
        'body': _broadcastBodyCtrl.text.trim(),
        'target': _broadcastTarget,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      _broadcastTitleCtrl.clear();
      _broadcastBodyCtrl.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Broadcast Sent!"), backgroundColor: Colors.purpleAccent)
        );
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Playground (Config)", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // --- GLOBAL CONTACT SETTINGS ---
              _buildSectionTitle("Global Contact Settings", Colors.blue),
              const SizedBox(height: 12),
              Form(
                key: _contactFormKey,
                child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _buildTextField("WhatsApp Support", "050...", Icons.chat, _whatsappCtrl, isDark),
                    const SizedBox(height: 16),
                    _buildTextField("Call Hotline", "053...", Icons.phone, _callCtrl, isDark),
                    const SizedBox(height: 16),
                    _buildTextField("Student Support Email", "support@stayhubgh.com", Icons.email, _adminEmailCtrl, isDark),
                    const SizedBox(height: 16),
                    _buildTextField("Agent Support Email", "support@stayhubgh.com", Icons.support_agent, _agentHelpEmailCtrl, isDark),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveConfig,
                        icon: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_isLoading ? "Saving..." : "Save Contact Settings"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
              
              // --- FINANCIAL SETTINGS MOVED TO EARNINGS VIEW ---

              const SizedBox(height: 30),

              // --- BROADCAST SECTION ---
              _buildSectionTitle("Announcements (Broadcast)", Colors.purple),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.withOpacity(0.3))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _broadcastTarget,
                      dropdownColor: cardColor,
                      decoration: InputDecoration(
                        labelText: "Target Audience",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All Users', child: Text("All Users", style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'All Students', child: Text("All Students")),
                        DropdownMenuItem(value: 'All Agents', child: Text("All Agents")),
                      ],
                      onChanged: (val) => setState(() => _broadcastTarget = val!),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField("Title", "Critical Update", Icons.title, _broadcastTitleCtrl, isDark),
                    const SizedBox(height: 16),
                    TextFormField(
                       controller: _broadcastBodyCtrl,
                       maxLines: 3,
                       style: TextStyle(color: isDark ? Colors.white : Colors.black),
                       decoration: InputDecoration(
                         labelText: "Message Body",
                         hintText: "Type your announcement here...",
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                         alignLabelWithHint: true,
                       ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendBroadcast,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text("Send Broadcast"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 30),
              
              // --- SCHOOL MANAGEMENT ---
              _buildSectionTitle("Dynamic School Management", Colors.green),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3))
                ),
                child: StreamBuilder<DocumentSnapshot>(
                   stream: FirebaseFirestore.instance.collection('config').doc('app_config').snapshots(),
                   builder: (context, snapshot) {
                     final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                     final schools = List<String>.from(data['available_schools'] ?? ['UENR', 'CUG', 'UDS']);
                     
                     return Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Wrap(
                           spacing: 8,
                           children: schools.map((s) => Chip(
                             label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
                             onDeleted: () async {
                               schools.remove(s);
                               await FirebaseFirestore.instance.collection('config').doc('app_config').update({'available_schools': schools});
                             },
                             deleteIconColor: Colors.red,
                           )).toList(),
                         ),
                         const SizedBox(height: 16),
                         Row(
                           children: [
                             Expanded(
                               child: TextField(
                                 onSubmitted: (val) async {
                                   if (val.trim().isNotEmpty && !schools.contains(val.trim())) {
                                     schools.add(val.trim());
                                     await FirebaseFirestore.instance.collection('config').doc('app_config').update({'available_schools': schools});
                                   }
                                 },
                                 decoration: InputDecoration(
                                   hintText: "School Name (e.g. KNUST)",
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                 ),
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 8),
                         const Text("Tip: Add the school name first, then coordinates via Firebase if map centering is needed.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                       ],
                     );
                   }
                )
              ),

              const SizedBox(height: 30),
              
              // --- SYSTEM CONTROL ---
              _buildSectionTitle("System Control", Colors.red),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: StreamBuilder<DocumentSnapshot>(
                   stream: FirebaseFirestore.instance.collection('config').doc('app_config').snapshots(),
                   builder: (context, snapshot) {
                     final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                     bool isMaintenance = data['maintenance_mode'] == true;
                     return SwitchListTile(
                       title: const Text("Maintenance Mode", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                       subtitle: const Text("Lock the app for all users (except Admins). Use with caution."),
                       value: isMaintenance,
                       secondary: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                       activeThumbColor: Colors.red,
                       onChanged: (val) async {
                         await FirebaseFirestore.instance.collection('config').doc('app_config').set({
                           'maintenance_mode': val
                         }, SetOptions(merge: true));
                       },
                     );
                   }
                )
              ),
              const SizedBox(height: 30),
              
               Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Changes made here update the app instantly for all users.", style: TextStyle(color: isDark ? Colors.blue[200] : Colors.blue[900], fontSize: 13))),
                  ],
                ),
              )
            ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.withOpacity(0.6), letterSpacing: 1));
  }

  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller, bool isDark) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      keyboardType: label.toLowerCase().contains("phone") || label.toLowerCase().contains("whatsapp") || label.toLowerCase().contains("call") ? TextInputType.phone : (label.toLowerCase().contains("email") ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
      ),
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
      onEditingComplete: () => FocusScope.of(context).nextFocus(),
    );
  }
}
