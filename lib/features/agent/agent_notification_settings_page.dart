import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgentNotificationSettingsPage extends StatefulWidget {
  const AgentNotificationSettingsPage({super.key});

  @override
  State<AgentNotificationSettingsPage> createState() => _AgentNotificationSettingsPageState();
}

class _AgentNotificationSettingsPageState extends State<AgentNotificationSettingsPage> {
  final _user = FirebaseAuth.instance.currentUser;
  bool _newBookings = true;
  bool _messages = true;
  bool _walletUpdates = true;
  bool _studioViews = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('agents').doc(_user!.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final settings = data['notification_settings'] as Map<String, dynamic>? ?? {};
        setState(() {
          _newBookings = settings['new_bookings'] ?? true;
          _messages = settings['messages'] ?? true;
          _walletUpdates = settings['wallet_updates'] ?? true;
          _studioViews = settings['studio_views'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool val) async {
    setState(() {
      if (key == 'new_bookings') _newBookings = val;
      if (key == 'messages') _messages = val;
      if (key == 'wallet_updates') _walletUpdates = val;
      if (key == 'studio_views') _studioViews = val;
    });

    if (_user == null) return;
    try {
      await FirebaseFirestore.instance.collection('agents').doc(_user!.uid).update({
        'notification_settings.$key': val,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildToggleTile(
                "New Bookings", 
                "Get alerts when a student books a room", 
                Icons.bookmark_added_rounded, 
                _newBookings, 
                (v) => _updateSetting('new_bookings', v),
                cardColor
              ),
              _buildToggleTile(
                "Messages", 
                "Instant alerts for student inquiries", 
                Icons.chat_bubble_outline_rounded, 
                _messages, 
                (v) => _updateSetting('messages', v),
                cardColor
              ),
              _buildToggleTile(
                "Wallet & Payouts", 
                "Notifications for earnings and cashouts", 
                Icons.account_balance_wallet_outlined, 
                _walletUpdates, 
                (v) => _updateSetting('wallet_updates', v),
                cardColor
              ),
              _buildToggleTile(
                "Studio Performance", 
                "Weekly reports on clip views and likes", 
                Icons.insights_rounded, 
                _studioViews, 
                (v) => _updateSetting('studio_views', v),
                cardColor
              ),
              
              const SizedBox(height: 32),
              _buildInfoBox(isDark),
            ],
          ),
    );
  }

  Widget _buildToggleTile(String title, String subtitle, IconData icon, bool val, Function(bool) onChanged, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: val,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.blueAccent, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        activeColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildInfoBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Syncing these preferences will update how we reach you via Push and Email.",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.blueAccent.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
