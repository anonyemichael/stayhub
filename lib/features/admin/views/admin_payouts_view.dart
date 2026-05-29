import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/services/firestore_service.dart';

class AdminPayoutsView extends StatefulWidget {
  const AdminPayoutsView({super.key});

  @override
  State<AdminPayoutsView> createState() => _AdminPayoutsViewState();
}

class _AdminPayoutsViewState extends State<AdminPayoutsView> {
  final _firestoreService = FirestoreService();
  final _currencyFmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('payouts').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No payout requests."));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final isPending = status == 'pending';
            final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPending ? Colors.orange.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['businessName'] ?? "Unknown Agent",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toString().toUpperCase(),
                          style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("PAYOUT AMOUNT", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(_currencyFmt.format(data['amount']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blueAccent)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(data['bankName'] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(data['accountNumber'] ?? "N/A", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showRejectDialog(doc.id, data),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("REJECT & REFUND"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _confirmApprove(doc.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("MARK AS PAID"),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (status == 'rejected') ...[
                    const SizedBox(height: 8),
                    Text("Reason: ${data['rejectionReason'] ?? 'No reason provided'}", style: const TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic)),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _confirmApprove(String payoutId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Payout"),
        content: const Text("Have you manually transferred the funds to the agent's account? This will mark the request as COMPLETED."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firestoreService.completePayout(payoutId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("YES, IT'S PAID"),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String payoutId, Map<String, dynamic> data) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Payout"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Reason for rejection"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              await _firestoreService.refundPayout(
                payoutId: payoutId,
                agentId: data['agentId'],
                amount: (data['amount'] as num).toDouble(),
                reason: reason,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("REJECT & REFUND"),
          ),
        ],
      ),
    );
  }
}
