import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/payment_service.dart';

class AgentBankPage extends StatefulWidget {
  const AgentBankPage({super.key});

  @override
  State<AgentBankPage> createState() => _AgentBankPageState();
}

class _AgentBankPageState extends State<AgentBankPage> {
  final _paymentService = PaymentService();
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  final _accountController = TextEditingController();
  final _businessNameController = TextEditingController(); 
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchBanks();
    _loadCurrentData();
  }

  Future<void> _fetchBanks() async {
    final banks = await _paymentService.getBanks();
    if (mounted) {
      setState(() {
        _banks = banks;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentData() async {
    final user = _auth.currentUser;
    if (user != null) {
      _businessNameController.text = user.displayName ?? "My Hostel Business";
    }
  }

  Future<void> _linkAccount() async {
    if (_selectedBank == null || _accountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a bank and enter account number")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = _auth.currentUser;
    if (user == null) return;

    // We use a FIXED FEE model (Global Commission in GHS).
    // Therefore, the subaccount itself is created with 0% percentage charge.
    // The actual fee is deducted per-transaction using 'transaction_charge'.
    
    // 1. Create Subaccount on Paystack
    final subAccountCode = await _paymentService.createSubAccount(
      businessName: _businessNameController.text,
      bankCode: _selectedBank!['code'],
      accountNumber: _accountController.text.trim(),
      percentage: "0.0", // 0% split rule on the account level
    );

    if (subAccountCode != null) {
      // 2. Save to Firestore
      await _firestoreService.updateAgentProfile(user.uid, {
        'paystack_subaccount_code': subAccountCode,
        'bank_name': _selectedBank!['name'],
        'account_number': _accountController.text.trim(),
        'is_bank_verified': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bank Account Linked Successfully!")),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to link account. Please check details.")),
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Link Bank Account"),
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())  
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                          ? [Colors.blue[900]!, Colors.purple[900]!] 
                          : [Colors.blue[700]!, Colors.purple[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Get Paid Instantly", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("Link your account to receive automatic split payments.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text("Account Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),

                  // Form
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        _buildStyledTextField(
                          controller: _businessNameController,
                          label: "Business Name",
                          icon: Icons.store,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildStyledDropdown(isDark),
                        const SizedBox(height: 20),
                        _buildStyledTextField(
                          controller: _accountController,
                          label: "Account Number",
                          icon: Icons.numbers,
                          isDark: isDark,
                          isNumber: true
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _linkAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5), // Admin Blue / Primary
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.blue.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("Link Account & Enable Payments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required bool isDark,
    bool isNumber = false,
  }) {
    final fillColor = isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[50]!;
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.blue[700]),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildStyledDropdown(bool isDark) {
    final fillColor = isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[50]!;
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedBank,
      isExpanded: true, // Fix Horizontal Overflow
      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: "Select Bank / MoMo",
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(Icons.account_balance, color: isDark ? Colors.grey[400] : Colors.blue[700]),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      items: _banks.map((bank) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: bank,
          child: Text(
            bank['name'], 
            overflow: TextOverflow.ellipsis,
            maxLines: 1, // Prevent multiline expansion
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedBank = val),
    );
  }
}
