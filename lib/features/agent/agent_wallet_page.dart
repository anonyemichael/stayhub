import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/features/agent/agent_bank_page.dart';
import 'package:intl/intl.dart'; 

class AgentWalletPage extends StatefulWidget {
  const AgentWalletPage({super.key});

  @override
  State<AgentWalletPage> createState() => _AgentWalletPageState();
}

class _AgentWalletPageState extends State<AgentWalletPage> {
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final _currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("Please log in"));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 130, 20, 100), // Increased top padding to 130 to clear AppBar
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PREMIUM WALLET CARD
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('agents').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                Map<String, dynamic> data = {};
                double balance = 0.0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  data = snapshot.data!.data() as Map<String, dynamic>;
                  final val = data['wallet_balance'] ?? data['walletBalance'];
                  balance = (val is String ? double.tryParse(val) : (val as num?)?.toDouble()) ?? 0.0;
                }
                return _buildPremiumWalletCard(balance, isDark, data);
              },
            ),
            
            const SizedBox(height: 32),

            // REFINED ACTION (Bank Setup only, since Withdraw is automated)
            _buildActionRow(context, isDark),

            const SizedBox(height: 40),

            // RECENT EARNINGS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recent Earnings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)),
                Text("See All", style: TextStyle(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // REAL TRANSACTION LIST
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('agents').doc(user.uid).collection('transactions').orderBy('date', descending: true).limit(15).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmptyState(isDark);

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildTransactionTile(data, isDark);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumWalletCard(double balance, bool isDark, Map<String, dynamic> data) {
    final bankName = data['bank_name'];
    final accNo = data['account_number'];
    final isLinked = bankName != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              if (isLinked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Row(
                    children: [
                      Icon(Icons.link, color: Colors.greenAccent, size: 12),
                      SizedBox(width: 4),
                      Text("LINKED", style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                   child: const Text("UNLINKED", style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _currencyFormat.format(balance),
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1),
                ),
              ),
              if (balance > 0)
                TextButton(
                  onPressed: () => _showWithdrawDialog(context, balance, data),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("WITHDRAW", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          if (isLinked) ...[
            const SizedBox(height: 12),
            Text("Payout: $bankName ($accNo)", style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
          ] else ...[
            const SizedBox(height: 12),
            const Text("Automated direct payouts pending setup.", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              _buildCardMiniStat("Earnings", "+12%", Colors.greenAccent),
              const SizedBox(width: 24),
              _buildCardMiniStat("Type", (data['partnerType'] ?? 'Agent').toUpperCase(), Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, double balance, Map<String, dynamic> data) {
    if (data['bank_name'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please link your bank account first.")),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentBankPage()));
      return;
    }

    final amountController = TextEditingController(text: balance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Withdraw Funds", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Amount to withdraw (GHS):", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "GHS ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Text("Will be sent to: ${data['bank_name']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text("A/C: ${data['account_number']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null || amt <= 0 || amt > balance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount")));
                return;
              }
              Navigator.pop(context);
              try {
                await _firestoreService.requestPayout(
                  uid: _auth.currentUser!.uid,
                  amount: amt,
                  bankName: data['bank_name'],
                  accountNumber: data['account_number'],
                  businessName: data['business_name'],
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Withdrawal request submitted!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request failed: $e")));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }

  Widget _buildCardMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentBankPage())),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Payout Configuration", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  Text("Manage linked bank and MoMo details", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> data, bool isDark) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final type = data['type'] ?? 'credit';
    final isCredit = type == 'credit';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? Colors.green : Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['description'] ?? 'Revenue Share', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(DateFormat('MMM dd, yyyy • hh:mm a').format(date), style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Text(
            "${isCredit ? '+' : '-'} ${_currencyFormat.format(amount)}",
            style: TextStyle(
              color: isCredit ? const Color(0xFF10B981) : Colors.redAccent,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 60, color: isDark ? Colors.white12 : Colors.grey[200]),
            const SizedBox(height: 16),
            const Text("No earnings recorded yet.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}