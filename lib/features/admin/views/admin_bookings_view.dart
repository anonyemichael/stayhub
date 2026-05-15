import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminBookingsView extends StatefulWidget {
  const AdminBookingsView({super.key});

  @override
  State<AdminBookingsView> createState() => _AdminBookingsViewState();
}

class _AdminBookingsViewState extends State<AdminBookingsView> {
  String _filterStatus = 'All'; // All, PAID, PENDING, CANCELLED
  final currencyFmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Global Bookings", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // Filter Chips
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list_rounded, color: textColor),
            onSelected: (val) => setState(() => _filterStatus = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text("All Transactions")),
              const PopupMenuItem(value: 'PAID', child: Text("Paid (Successful)")),
              const PopupMenuItem(value: 'PENDING', child: Text("Pending")),
              const PopupMenuItem(value: 'CANCELLED', child: Text("Cancelled")),
            ],
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings')
            .orderBy('bookingDate', descending: true)
            .limit(100) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.blue));
          }

          final allDocs = List<DocumentSnapshot>.from(snapshot.data!.docs);
          
          // Sort client-side safely
          try {
            allDocs.sort((a, b) {
               final da = _safelyGetDate(a.data());
               final db = _safelyGetDate(b.data());
               if (da == null && db == null) return 0;
               if (da == null) return 1; 
               if (db == null) return -1;
               return db.compareTo(da); 
            });
          } catch (e) {
            debugPrint("Sorting Error: $e");
          }

          final docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'UNKNOWN').toString().toUpperCase();
            if (_filterStatus == 'All') return true;
            return status == _filterStatus.toUpperCase();
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.withOpacity(0.3)),
                   const SizedBox(height: 16),
                   Text("No bookings found", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                   if (_filterStatus != 'All')
                      TextButton(
                        onPressed: () => setState(() => _filterStatus = 'All'), 
                        child: const Text("Clear Filter")
                      )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'UNKNOWN';
              final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final fee = (data['platformFee'] as num?)?.toDouble() ?? 0.0;
              final agentShare = amount - fee;
              final date = (data['bookingDate'] as Timestamp?)?.toDate();
              final bookingId = docs[index].id;
              final splitCode = data['subaccount_code'] ?? 'N/A';
              final hostelName = data['hostelName'] ?? 'Unknown Hostel';
              final rawRoomType = data['roomType'] ?? 'Standard Room';
              final roomCap = data['capacity']?.toString() ?? '?';
              final roomType = rawRoomType.replaceAll('-', ' ');

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  border: Border.all(color: _getStatusColor(status).withOpacity(0.3), width: 1.5)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: ID and Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(bookingId.toUpperCase(), style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 10)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Main Info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], shape: BoxShape.circle),
                          child: Icon(Icons.apartment_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hostelName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                            Text(
                               !roomType.toLowerCase().contains('in a room') 
                                 ? "$roomType ($roomCap in a room)" 
                                 : roomType, 
                               style: TextStyle(color: Colors.grey[500], fontSize: 13)
                             ),
                          ],
                        ))
                      ],
                    ),
                    
                    const Divider(height: 24, thickness: 0.5),
                    
                    // Split Payment Breakdown (The God Mode Part)
                    Row(
                       children: [
                         Icon(Icons.hub_rounded, size: 12, color: Colors.grey[400]),
                         const SizedBox(width: 6),
                         Text("PAYSTACK SPLIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[500], letterSpacing: 1)),
                       ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Agent Share
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Agent Share", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(currencyFmt.format(agentShare), style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 13)),
                                Text("Code: $splitCode", style: TextStyle(color: Colors.grey[400], fontSize: 9)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                         // Platform Share
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Platform Fee", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(currencyFmt.format(fee), style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 13)),
                                const Text("Direct Revenue", style: TextStyle(color: Colors.grey, fontSize: 9)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    if (date != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      )
                    ]
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toUpperCase()) {
      case 'PAID': return Colors.green;
      case 'PENDING': return Colors.orange;
      case 'CANCELLED': return Colors.red;
      case 'CONFIRMED': return Colors.blue; 
      default: return Colors.grey;
    }
  }

  DateTime? _safelyGetDate(Object? data) {
    if (data is! Map) return null;
    final val = data['bookingDate'];
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
