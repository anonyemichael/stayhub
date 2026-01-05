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
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
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
                  final rawBal = data['walletBalance']; // Note: field name in FirestoreService might be 'wallet_balance'
                  // Checking FirestoreService.updateBookingStatus: 'wallet_balance'
                  // Checking previous code: data['walletBalance']...
                  // I should probably support both or verify which one used?
                  // Step 716 code used 'walletBalance'. 
                  // But FirestoreService Step 610 writes 'wallet_balance'. 
                  // I'll check both to be safe, defaulting to 0.
                  final val = data['wallet_balance'] ?? data['walletBalance'];
                  balance = (val is String ? double.tryParse(val) : (val as num?)?.toDouble()) ?? 0.0;
                }
                return _buildCreditCard(balance, isDark);
              },
            ),
            
            const SizedBox(height: 16),

            // 1.5. BANK LINK STATUS
            StreamBuilder<DocumentSnapshot>(
              stream: _firestoreService.getAgentProfile(user.uid),
              builder: (context, snapshot) {
                 bool isLinked = false;
                 if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    isLinked = data['is_bank_verified'] == true;
                 }
                 return _buildBankLinkTile(isLinked, isDark);
              },
            ),

            const SizedBox(height: 30),

            // 2. TRANSACTIONS HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recent Earnings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                Icon(Icons.history, color: isDark ? Colors.grey[400] : Colors.grey[400]),
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
                  if (docs.isEmpty) return _buildEmptyState(isDark);

                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildTransactionTile(docs[index].data() as Map<String, dynamic>, isDark);
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

  Widget _buildCreditCard(double balance, bool isDark) {
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
                child: const Icon(Icons.credit_card, size: 16, color: Colors.black45), 
              ),
              const Text("StayHub Earnings", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
            ],
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Total Earnings", style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: const Text("AUTO-PAID", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currencyFormat.format(balance),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
            ],
          ),

          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                 child: Text("**** BANK", style: TextStyle(color: Colors.white54, letterSpacing: 2), overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 4),
                  Text("Direct Deposit", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankLinkTile(bool isLinked, bool isDark) {
    if (isLinked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Expanded(child: Text("Bank Account Active on Paystack", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentBankPage()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Connect Bank Account", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text("Link now to receive payments instantly.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> data, bool isDark) {
    // Logic for display
    final isExpense = data['type'] == 'payout' || data['type'] == 'expense';
    final rawAmt = data['amount'];
    final amount = (rawAmt is String ? double.tryParse(rawAmt) : (rawAmt as num?)?.toDouble()) ?? 0.0;
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = data['status'] ?? 'completed';
    // Payouts are now "Credits" to the agent's actual bank, so we treat them as Income records primarily.
    // If we have 'type': 'credit', it's income.
    
    // Formatting date
    final dateString = DateFormat('MMM d, h:mm a').format(date);
    
    final tileColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.south_west, color: Colors.green), // Always incoming for earnings
          ),
          const SizedBox(width: 16),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['description'] ?? 'Earning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor)),
                const SizedBox(height: 4),
                Text(dateString, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),

          // Amount
          Text(
            "+ ${_currencyFormat.format(amount)}",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[700]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 60, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No earnings yet", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400])),
        ],
      ),
    );
  }
}