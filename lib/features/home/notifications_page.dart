import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _clearAll() async {
    if (user == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Notifications?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("This will permanently remove all your notifications."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("CLEAR ALL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900))
          ),
        ],
      )
    );

    if (confirm == true) {
      final snapshots = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared"), backgroundColor: Colors.black87)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Alerts Center',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: firestoreService.getUserNotifications(user?.uid ?? ''),
            builder: (context, snapshot) {
              final hasData = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              if (!hasData) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.redAccent),
                label: const Text("CLEAR", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? Center(child: Text("Please log in to see notifications", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)))
          : StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getUserNotifications(user!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildNotificationCard(doc.id, data, isDark, theme);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 80, color: Colors.blueAccent.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            "Inbox is Empty",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll notify you about your bookings and updates.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(String id, Map<String, dynamic> data, bool isDark, ThemeData theme) {
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isRead = data['isRead'] ?? false;
    final type = data['type'] ?? 'general';

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('notifications')
            .doc(id)
            .delete();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isRead ? (isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white) : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isRead ? Colors.transparent : Colors.blueAccent.withOpacity(0.1),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isRead ? 0.02 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            if (!isRead) {
              firestoreService.markNotificationAsRead(user!.uid, id);
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTypeIcon(type, isRead, isDark),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: isRead ? Colors.grey : null,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(timestamp),
                            style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: TextStyle(
                          color: isRead ? Colors.grey : Colors.grey[600],
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type, bool isRead, bool isDark) {
    IconData iconData;
    Color color;

    switch (type) {
      case 'booking':
        iconData = Icons.calendar_today_rounded;
        color = Colors.green;
        break;
      case 'payment':
        iconData = Icons.account_balance_wallet_rounded;
        color = Colors.orange;
        break;
      case 'system':
        iconData = Icons.auto_awesome_rounded;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.notifications_rounded;
        color = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isRead ? Colors.grey : color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(iconData, color: isRead ? Colors.grey : color, size: 22),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}
