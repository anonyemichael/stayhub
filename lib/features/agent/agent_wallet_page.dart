import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:intl/intl.dart'; // Add to pubspec.yaml

class AgentWalletPage extends StatefulWidget {
  const AgentWalletPage({super.key});

  @override
  State<AgentWalletPage> createState() => _AgentWalletPageState();
}

class _AgentWalletPageState extends State<AgentWalletPage> {
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  final _currencyFormat = NumberFormat.currency(locale: 'en_GH', symbol: '₵');

  // --- PAYOUT SHEET LOGIC ---
  void _showPayoutSheet(double currentBalance) {
    if (currentBalance <= 0) {
      _showSnack("Insufficient balance for payout.", isError: true);
      return;
    }

    final amountController = TextEditingController();
    final detailsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to go full height if needed
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75, // Take up 75% of screen
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),

            const Text("Request Withdrawal", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Available: ${_currencyFormat.format(currentBalance)}", style: TextStyle(color: Colors.grey[600])),

            const SizedBox(height: 30),

            // Amount Input
            _buildSoftInput(amountController, "Amount (GHS)", Icons.attach_money, isNumber: true),

            // Quick Chips
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickChip("₵100", amountController),
                _buildQuickChip("50%", amountController, percentage: 0.5, balance: currentBalance),
                _buildQuickChip("Max", amountController, percentage: 1.0, balance: currentBalance),
              ],
            ),

            const SizedBox(height: 24),

            // Details Input
            _buildSoftInput(detailsController, "Momo Number / Bank Details", Icons.account_balance),

            const Spacer(),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  final details = detailsController.text.trim();

                  if (amount == null || amount <= 0 || amount > currentBalance) {
                    _showSnack("Invalid amount.", isError: true);
                    return;
                  }
                  if (details.isEmpty) {
                    _showSnack("Please provide payment details.", isError: true);
                    return;
                  }

                  Navigator.pop(context);

                  // Execute Transaction
                  final user = _auth.currentUser;
                  if (user != null) {
                    await _firestoreService.requestPayout(user.uid, amount, "MOMO", details);
                    _showSnack("Payout request submitted!");
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: const Text("Confirm Withdrawal", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("Please log in"));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // 1. PREMIUM CREDIT CARD
            StreamBuilder<DocumentSnapshot>(
              stream: _firestoreService.getWalletBalance(user.uid),
              builder: (context, snapshot) {
                double balance = 0.0;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final rawBal = data['walletBalance'];
                  balance = (rawBal is String ? double.tryParse(rawBal) : (rawBal as num?)?.toDouble()) ?? 0.0;
                }
                return _buildCreditCard(balance);
              },
            ),

            const SizedBox(height: 30),

            // 2. TRANSACTIONS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Icon(Icons.filter_list, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),

            // 3. TRANSACTIONS LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getUserTransactions(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return _buildEmptyState();

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildTransactionTile(docs[index].data() as Map<String, dynamic>);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildCreditCard(double balance) {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)], // "Moonlit Asteroid"
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF203A43).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chip Icon
              Container(
                width: 45, height: 30,
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.yellowAccent.withOpacity(0.5)),
                ),
                child: const Icon(Icons.wifi, size: 16, color: Colors.black45), // NFC symbol lookalike
              ),
              const Text("StayHub Agent", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
            ],
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Balance", style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                _currencyFormat.format(balance),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("**** **** 8291", style: TextStyle(color: Colors.white54, letterSpacing: 2)),
              InkWell(
                onTap: () => _showPayoutSheet(balance),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text("Withdraw", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> data) {
    // Logic for display
    final isExpense = data['type'] == 'payout' || data['type'] == 'expense';
    final rawAmt = data['amount'];
    final amount = (rawAmt is String ? double.tryParse(rawAmt) : (rawAmt as num?)?.toDouble()) ?? 0.0;
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = data['status'] ?? 'completed';
    final isPending = status == 'pending';

    // Formatting date
    final dateString = DateFormat('MMM d, h:mm a').format(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isExpense ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isExpense ? Icons.north_east : Icons.south_west, // Arrow up/right for out, down/left for in
              color: isExpense ? Colors.orange : Colors.green,
            ),
          ),
          const SizedBox(width: 16),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? 'Transaction', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(dateString, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),

          // Amount & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${isExpense ? '-' : '+'} ${_currencyFormat.format(amount)}",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isExpense ? Colors.black87 : Colors.green[700]
                ),
              ),
              if (isPending)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)),
                  child: Text("Processing", style: TextStyle(fontSize: 10, color: Colors.amber[900], fontWeight: FontWeight.bold)),
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSoftInput(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, TextEditingController controller, {double? percentage, double? balance}) {
    return GestureDetector(
      onTap: () {
        if (percentage != null && balance != null) {
          controller.text = (balance * percentage).toStringAsFixed(2);
        } else {
          // Hardcoded value for "100"
          controller.text = "100";
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No transactions yet", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}