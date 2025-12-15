import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:share_plus/share_plus.dart';

class AgentBookingsPage extends StatefulWidget {
  const AgentBookingsPage({super.key});

  @override
  State<AgentBookingsPage> createState() => _AgentBookingsPageState();
}

class _AgentBookingsPageState extends State<AgentBookingsPage> {
  final _auth = FirebaseAuth.instance;
  final _currencyFormat = NumberFormat.currency(locale: 'en_GH', symbol: '₵');

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text("Authentication required."));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No bookings for your hostels yet.", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final bookingDate = (data['bookingDate'] as Timestamp?)?.toDate() ?? DateTime.now();
              final status = data['status'] ?? 'PENDING';
              final isPending = status == 'PENDING';
              final bookingId = docs[index].id;
              final userId = data['userId']; // Needed for update

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: isPending ? BorderSide(color: Colors.orange.shade300, width: 2) : BorderSide.none),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['hostelName'] ?? 'Hostel',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPending ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(status, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isPending ? Colors.orange : Colors.green)),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.person, "Student", data['userName'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.wc, "Sex", data['studentSex'] ?? 'Not Specified'), // New
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.tag, "Ticket ID", bookingId, isMono: true), // Requested
                      const SizedBox(height: 16),
                      
                      if (isPending)
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      // Correctly find or create a chat for this user-agent pair
                                      final currentUser = FirebaseAuth.instance.currentUser;
                                      if (currentUser == null) return;
                                      
                                      final studentId = userId; // From booking data
                                      final agentId = currentUser.uid;

                                      // 1. Check for existing chat
                                      final chatsRef = FirebaseFirestore.instance.collection('chats');
                                      final query = await chatsRef
                                          .where('users', arrayContains: agentId)
                                          .get();

                                      String? targetChatId;
                                      // Client-side filtering for the second user because Firestore can't arrayContains two values easily in one query without complex index
                                      for (var doc in query.docs) {
                                        final users = List<String>.from(doc['users']);
                                        if (users.contains(studentId)) {
                                          targetChatId = doc.id;
                                          break;
                                        }
                                      }

                                      // 2. Create if not exists
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
                                    },
                                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                    label: const Text("Chat"),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Share.share("Hello ${data['userName']}, please pay GHS ${data['price']} via Mobile Money to 0551234567 to confirm your booking at ${data['hostelName']}. Booking ID: $bookingId");
                                    },
                                    icon: const Icon(Icons.share, size: 16),
                                    label: const Text("Pay Req"),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.purple),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await FirebaseFirestore.instance.collection('users').doc(userId).collection('bookings').doc(bookingId).update({'status': 'REJECTED'});
                                    },
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text("Reject"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await FirestoreService().updateBookingStatus(userId, bookingId, 'CONFIRMED');
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text("Approve", style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text(
                              "Earnings: ${_currencyFormat.format(data['agentPrice'] ?? (data['price'] ?? 0) - 50)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                            ),
                            Text(
                              "Total: ${_currencyFormat.format(data['price'] ?? 0.0)}",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16),
                            ),
                          ],
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

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isMono = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
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
}
