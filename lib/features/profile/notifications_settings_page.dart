import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stayhub/services/firestore_service.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

// Added WidgetsBindingObserver to detect when user returns from Settings app
class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- State Variables ---
  bool _isLoading = true;
  bool _systemPermissionGranted = false; // Tracks OS level permission

  // App Settings
  bool _pauseAll = false;
  bool _bookingsEnabled = true;
  bool _messagesEnabled = true;
  bool _marketingEnabled = false;

  // Creative Feature: Quiet Hours
  bool _quietModeEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to app lifecycle
    _initData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // "Realness": Check permissions when app resumes from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemPermissions();
    }
  }

  Future<void> _initData() async {
    await _checkSystemPermissions();
    await _loadSettings();
  }

  Future<void> _checkSystemPermissions() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _systemPermissionGranted = status.isGranted;
      });
    }
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final settings = data['notificationSettings'] as Map<String, dynamic>? ?? {};

        // Parse Quiet Hours
        final startHour = settings['quietStartHour'] ?? 22;
        final startMin = settings['quietStartMin'] ?? 0;
        final endHour = settings['quietEndHour'] ?? 7;
        final endMin = settings['quietEndMin'] ?? 0;

        if (mounted) {
          setState(() {
            _pauseAll = settings['pauseAll'] ?? false;
            _bookingsEnabled = settings['bookingsEnabled'] ?? true;
            _messagesEnabled = settings['messagesEnabled'] ?? true;
            _marketingEnabled = settings['marketingEnabled'] ?? false;
            _quietModeEnabled = settings['quietModeEnabled'] ?? false;
            _quietStart = TimeOfDay(hour: startHour, minute: startMin);
            _quietEnd = TimeOfDay(hour: endHour, minute: endMin);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Unified save method
  Future<void> _saveSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Haptic feedback makes the switch feel "real"
    HapticFeedback.lightImpact();

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'notificationSettings': {
          'pauseAll': _pauseAll,
          'bookingsEnabled': _bookingsEnabled,
          'messagesEnabled': _messagesEnabled,
          'marketingEnabled': _marketingEnabled,
          'quietModeEnabled': _quietModeEnabled,
          'quietStartHour': _quietStart.hour,
          'quietStartMin': _quietStart.minute,
          'quietEndHour': _quietEnd.hour,
          'quietEndMin': _quietEnd.minute,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> _requestSystemPermission() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied) {
      _showSettingsDialog();
    } else {
      _checkSystemPermissions();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("System Permissions"),
        content: const Text("StayHub needs notification permissions to send you booking alerts. Please enable them in Settings."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) _quietStart = picked;
        else _quietEnd = picked;
      });
      _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // If "Pause All" is on, or System Permissions are off, we visually dim the specific controls
    final bool globalDisable = _pauseAll || !_systemPermissionGranted;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- SECTION 1: SYSTEM MASTER SWITCH ---
          // Real apps warn you if the OS has blocked notifications completely
          if (!_systemPermissionGranted)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_off, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Notifications Disabled", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 2),
                        Text("Enable inside System Settings to receive alerts.", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text("Fix"),
                  )
                ],
              ),
            ),

          _buildSectionHeader("Preferences"),

          // Creative: Custom "Pause All" Card
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.all(16),
              secondary: CircleAvatar(
                backgroundColor: _pauseAll ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.1),
                child: Icon(
                  _pauseAll ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: _pauseAll ? Colors.orange : Colors.green,
                ),
              ),
              title: const Text("Pause All", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text("Temporarily mute all StayHub alerts."),
              value: _pauseAll,
              activeColor: Colors.orange,
              onChanged: (val) {
                setState(() => _pauseAll = val);
                _saveSettings();
              },
            ),
          ),

          const SizedBox(height: 24),

          // --- SECTION 2: SPECIFIC CHANNELS ---
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: globalDisable ? 0.5 : 1.0,
            child: AbsorbPointer(
              absorbing: globalDisable,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Channels"),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildCustomTile(
                          icon: Icons.bookmark_added_rounded,
                          color: Colors.blueAccent,
                          title: "Bookings",
                          subtitle: "Check-in details & confirmations",
                          value: _bookingsEnabled,
                          onChanged: (v) { setState(() => _bookingsEnabled = v); _saveSettings(); },
                        ),
                        _buildDivider(isDark),
                        _buildCustomTile(
                          icon: Icons.chat_bubble_rounded,
                          color: Colors.purpleAccent,
                          title: "Messages",
                          subtitle: "Chat with hosts or guests",
                          value: _messagesEnabled,
                          onChanged: (v) { setState(() => _messagesEnabled = v); _saveSettings(); },
                        ),
                        _buildDivider(isDark),
                        _buildCustomTile(
                          icon: Icons.local_offer_rounded,
                          color: Colors.pinkAccent,
                          title: "Marketing",
                          subtitle: "Promotions and tips",
                          value: _marketingEnabled,
                          onChanged: (v) { setState(() => _marketingEnabled = v); _saveSettings(); },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- SECTION 3: QUIET HOURS (Creative Addition) ---
                  _buildSectionHeader("Quiet Hours"),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.nights_stay, color: Colors.indigoAccent),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text("Enable Quiet Mode", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                            Switch(
                              value: _quietModeEnabled,
                              onChanged: (v) { setState(() => _quietModeEnabled = v); _saveSettings(); },
                              activeColor: Colors.indigoAccent,
                            ),
                          ],
                        ),
                        if (_quietModeEnabled) ...[
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTimeCard("Start", _quietStart, () => _pickTime(true), isDark),
                              Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
                              _buildTimeCard("End", _quietEnd, () => _pickTime(false), isDark),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "We won't send push notifications during this time.",
                            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildCustomTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeColor: color,
    );
  }

  Widget _buildTimeCard(String label, TimeOfDay time, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
          color: isDark ? Colors.black26 : Colors.grey[50],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, indent: 64, color: isDark ? Colors.white10 : Colors.grey[100]);
  }
}