import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/app_config_service.dart';

class AdminConfigView extends StatefulWidget {
  const AdminConfigView({super.key});

  @override
  State<AdminConfigView> createState() => _AdminConfigViewState();
}

class _AdminConfigViewState extends State<AdminConfigView> {
  final _contactFormKey = GlobalKey<FormState>();
  // final _configService = AppConfigService(); // REMOVED to force direct Firestore usage

  // Controllers for Support Config
  final _studentWhatsappCtrl = TextEditingController();
  final _studentEmailCtrl = TextEditingController();
  final _agentHelpEmailCtrl = TextEditingController();
  
  // Controllers for Admin Contact
  final _adminPhoneCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  
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
      // Direct Firestore Fetch (Bypassing Service to ensure consistency)
      final doc = await FirebaseFirestore.instance.collection('config').doc('app_config').get();
      final data = doc.data() ?? {};
      
      final studentSupport = data['student_support'] as Map<String, dynamic>? ?? {};
      final agentSupport = data['agent_support'] as Map<String, dynamic>? ?? {};
      final adminContact = data['admin_contact'] as Map<String, dynamic>? ?? {};

      // Logic: Admin Phone controls 'Student WhatsApp' essentially.
      // We load from student_support as primary, fallback to admin_contact
      _adminPhoneCtrl.text = studentSupport['whatsapp'] ?? adminContact['phone'] ?? '233509483401';
      _adminEmailCtrl.text = studentSupport['email'] ?? adminContact['email'] ?? 'support@stayhub.app';
      
      _agentHelpEmailCtrl.text = agentSupport['email'] ?? 'agents@stayhub.app';

      // Cleaned up unused controllers: _studentWhatsappCtrl, _studentEmailCtrl unused by new UI
    } catch (e) {
      debugPrint("Error loading config: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_contactFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    // Sanitize Phone: Default to Ghana (233) if user types 0...
    String phone = _adminPhoneCtrl.text.trim();
    if (phone.startsWith('0')) {
      phone = '233${phone.substring(1)}';
    } else if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }

    try {
      // Direct Firestore Write (config/app_config)
      await FirebaseFirestore.instance.collection('config').doc('app_config').set({
        // 1. Universal Student Support (used by HelpPage)
        'student_support': {
          'whatsapp': phone,
          'email': _adminEmailCtrl.text.trim(),
        },
        // 2. Agent Support (Independent)
        'agent_support': {
          'email': _agentHelpEmailCtrl.text.trim(),
        },
        // 3. Admin Contact (Legacy/Global backup)
        'admin_contact': {
          'phone': phone,
          'email': _adminEmailCtrl.text.trim(),
        }
      }, SetOptions(merge: true));
      
      // Update the UI controller to reflect the saved format
      _adminPhoneCtrl.text = phone;
      
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

  // Same build method, just inserting new section before the info container
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
                    _buildTextField("Support Phone / WhatsApp", "+233...", Icons.phone, _adminPhoneCtrl, isDark),
                    const SizedBox(height: 16),
                    _buildTextField("Student Support Email", "support@stayhub.app", Icons.email, _adminEmailCtrl, isDark),
                    const SizedBox(height: 16),
                    _buildTextField("Agent Support Email", "agents@stayhub.app", Icons.support_agent, _agentHelpEmailCtrl, isDark),
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
              
              const SizedBox(height: 30),

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
                      value: _broadcastTarget,
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
      keyboardType: label.toLowerCase().contains("phone") ? TextInputType.phone : (label.toLowerCase().contains("email") ? TextInputType.emailAddress : TextInputType.text),
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
