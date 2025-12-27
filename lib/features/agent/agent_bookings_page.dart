import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stayhub/services/notification_service.dart';

class AgentBookingsPage extends StatefulWidget {
  const AgentBookingsPage({super.key});

  @override
  State<AgentBookingsPage> createState() => _AgentBookingsPageState();
}

class _AgentBookingsPageState extends State<AgentBookingsPage> {
  final _auth = FirebaseAuth.instance;
  final _currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text("Authentication required."));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('bookings')
            .where('agentId', isEqualTo: user.uid)
            .orderBy('bookingDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: textColor)));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No bookings for your hostels yet.", style: TextStyle(color: subTextColor)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final bookingDate = (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now();
              final status = data['status'] ?? 'PENDING';
              final isPending = status == 'PENDING';
              final bookingId = docs[index].id;
              final userId = data['userId']; 

              return Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: isPending ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['hostelName'] ?? 'Hostel',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isPending ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3))
                            ),
                            child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isPending ? Colors.orange : Colors.green)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? Colors.grey[800] : Colors.grey[100], height: 1),
                      const SizedBox(height: 16),
                      
                      _buildInfoRow(Icons.person, "Student", data['userName'] ?? 'N/A', textColor, subTextColor),
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.wc, "Sex", data['studentSex'] ?? 'Not Specified', textColor, subTextColor), 
                      const SizedBox(height: 10),
                      _buildInfoRow(Icons.tag, "Ticket ID", bookingId, textColor, subTextColor, isMono: true),
                      
                      const SizedBox(height: 20),
                      
                      if (isPending)
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    context, 
                                    label: "Chat", 
                                    icon: Icons.chat_bubble_outline, 
                                    color: Colors.blue, 
                                    onTap: () => _openChat(context, userId, data)
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    context, 
                                    label: "Request", 
                                    icon: Icons.payments_outlined, 
                                    color: Colors.purple, 
                                    onTap: () => Share.share("Hello ${data['userName']}, please pay GHS ${data['price']} via Mobile Money to 0551234567 to confirm your booking at ${data['hostelName']}. Booking ID: $bookingId")
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    context, 
                                    label: "Reject", 
                                    icon: Icons.close, 
                                    color: Colors.red, 
                                    isOutlined: true,
                                    onTap: () async {
                                      await FirebaseFirestore.instance.collection('users').doc(userId).collection('bookings').doc(bookingId).update({'status': 'REJECTED'});
                                    }
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await FirestoreService().updateBookingStatus(userId, bookingId, 'CONFIRMED');
                                      // Notify Agent locally as confirmation
                                      await NotificationService().showNotification(
                                        title: 'Booking Approved', 
                                        body: 'You have confirmed the booking for ${data['userName']}'
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0
                                    ),
                                    child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text("Agent Earnings", style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.bold)),
                                   Text(
                                    _currencyFormat.format(data['agentPrice'] ?? (data['price'] ?? 0) - 50),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                                  ),
                                 ],
                               ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("Total Paid", style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.bold)),
                                  Text(
                                    _currencyFormat.format(data['price'] ?? 0.0),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor, Color? subTextColor, {bool isMono = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subTextColor),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: subTextColor, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontFamily: isMono ? 'monospace' : null,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap, bool isOutlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isOutlined ? 0.5 : 0.1))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, String studentId, Map<String, dynamic> data) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final agentId = currentUser.uid;
    final chatsRef = FirebaseFirestore.instance.collection('chats');
    final query = await chatsRef.where('users', arrayContains: agentId).get();

    String? targetChatId;
    for (var doc in query.docs) {
      final users = List<String>.from(doc['users']);
      if (users.contains(studentId)) {
        targetChatId = doc.id;
        break;
      }
    }

    if (targetChatId == null) {
      final newChat = await chatsRef.add({
        'users': [agentId, studentId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'hostelName': data['hostelName'] ?? 'Hostel',
        'studentName': data['userName'] ?? 'Student',
        'hostelId': data['hostelId'] ?? '', 
      });
      targetChatId = newChat.id;
    }

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
        chatId: targetChatId!, 
        otherUserName: data['userName'] ?? 'Student', 
        otherUserId: studentId
      )));
    }
  }
}
