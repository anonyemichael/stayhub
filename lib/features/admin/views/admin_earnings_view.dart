import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/services/firestore_service.dart';

class AdminEarningsView extends StatefulWidget {
  const AdminEarningsView({super.key});

  @override
  State<AdminEarningsView> createState() => _AdminEarningsViewState();
}

class _AdminEarningsViewState extends State<AdminEarningsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Financials", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: "Live Splits"),
            Tab(text: "Settings"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SplitLogTab(), 
          _SettingsTab(),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _firestoreService = FirestoreService();
  double _currentCommission = 50.0;
  bool _isLoading = true;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCommission();
  }

  Future<void> _loadCommission() async {
    final val = await _firestoreService.getGlobalCommission();
    if (mounted) {
      setState(() {
        _currentCommission = val;
        _controller.text = val.toStringAsFixed(2);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCommission() async {
    final val = double.tryParse(_controller.text);
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount")));
      return;
    }
    setState(() => _isLoading = true);
    await _firestoreService.setGlobalCommission(val);
    if (mounted) {
      setState(() {
        _currentCommission = val;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commission Rate Updated!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Commission Control",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 10),
          Text(
            "This fixes the flat fee the platform takes before sending the rest to the Agent via Paystack Split.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                 Row(
                   children: [
                     const Icon(Icons.percent, color: Colors.blue, size: 30),
                     const SizedBox(width: 16),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text("Platform Commission", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark?Colors.white:Colors.black)),
                           Text("Current: ${_currentCommission.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                         ],
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 20),
                 Text(
                   "This percentage is deducted from the Agent's earning. The student sees the original price.",
                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                 ),
                 const SizedBox(height: 10),
                 TextField(
                   controller: _controller,
                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   style: TextStyle(color: isDark ? Colors.white : Colors.black),
                   decoration: InputDecoration(
                     labelText: "New Percentage",
                     hintText: "e.g. 2.0",
                     border: const OutlineInputBorder(),
                     suffixText: "%",
                     filled: true,
                     fillColor: isDark ? Colors.black26 : Colors.white,
                     labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey)
                   ),
                 ),
                 const SizedBox(height: 20),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: _isLoading ? null : _updateCommission,
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.all(16),
                       backgroundColor: Colors.blue[800],
                       foregroundColor: Colors.white,
                     ),
                     child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Update Commission Rate"),
                   ),
                 )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitLogTab extends StatelessWidget {
  const _SplitLogTab();

  @override
  Widget build(BuildContext context) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
     final currencyFmt = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

     return StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance.collection('bookings')
           .limit(100) // Show last 100 transactions (filter client-side)
           .snapshots(),
       builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);
          
          // Client-side sort safely
          try {
            docs.sort((a, b) {
               final dataA = a.data() as Map<String, dynamic>?;
               final dataB = b.data() as Map<String, dynamic>?;
               
               DateTime? dateA;
               DateTime? dateB;

               if (dataA != null) {
                  final val = dataA['createdAt'] ?? dataA['timestamp'] ?? dataA['bookingDate'];
                  if (val is Timestamp) {
                    dateA = val.toDate();
                  } else if (val is String) dateA = DateTime.tryParse(val);
               }
               
               if (dataB != null) {
                  final val = dataB['createdAt'] ?? dataB['timestamp'] ?? dataB['bookingDate'];
                  if (val is Timestamp) {
                    dateB = val.toDate();
                  } else if (val is String) dateB = DateTime.tryParse(val);
               }

               if (dateA == null && dateB == null) return 0;
               if (dateA == null) return 1;
               if (dateB == null) return -1;
               return dateB.compareTo(dateA); 
            });
          } catch (e) {
             debugPrint("Sort Error: $e");
          }

          final paidDocs = docs.where((d) {
             final data = d.data() as Map<String, dynamic>?;
             final status = data?['status']?.toString().toUpperCase();
             return status == 'PAID';
          }).toList();

          if (paidDocs.isEmpty) return const Center(child: Text("No transactions yet."));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: paidDocs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
               final data = paidDocs[index].data() as Map<String, dynamic>;
               final amounts = data['amounts'] as Map<String, dynamic>?;
               
               final fee = (amounts?['commission'] as num?)?.toDouble() ?? 0.0;
               final base = (amounts?['base'] as num?)?.toDouble() ?? 0.0;
               final subcode = data['subaccountUsed'] ?? 'Admin Handled';

               return Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 decoration: BoxDecoration(
                   color: cardColor,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.green.withOpacity(0.2))
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("Payment Received", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                         Text("${data['hostelName'] ?? 'Unknown'}", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                         Text("Sub: $subcode", style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                       ],
                     ),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: [
                         Text("+ ${currencyFmt.format(fee)} (Platform)", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                         Text("Hostel Base: ${currencyFmt.format(base)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                       ],
                     )
                   ],
                 ),
               );
            },
          );
       },
     );
  }
}
