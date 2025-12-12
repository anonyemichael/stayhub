import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// A dedicated page for Agents to see bookings for THEIR hostels.

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
        // THE CORE LOGIC: Find all hostels belonging to this agent, then query bookings for those hostels.
        // This is more complex than a user's view, so we handle it carefully.
        stream: FirebaseFirestore.instance
            .collectionGroup('bookings') // Query across all users' booking sub-collections
            .where('agentId', isEqualTo: user.uid) // Filter by agentId stored in the booking
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

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Hostel Name & Price
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
                          Text(
                            _currencyFormat.format(data['price'] ?? 0.0),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 16),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Middle Row: User & Date
                      _buildInfoRow(Icons.person, "Booked by", data['userName'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.calendar_today, "Booking Date", DateFormat('MMM d, yyyy').format(bookingDate)),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.tag, "Booking ID", docs[index].id, isMono: true),
                      
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () {}, child: const Text("Contact User")),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
                            child: const Text("View Details", style: TextStyle(color: Colors.white)),
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
