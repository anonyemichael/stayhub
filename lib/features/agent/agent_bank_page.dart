import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      _businessNameController.text = user.displayName ?? "My Business";
      
      final snapshot = await FirebaseFirestore.instance.collection('agents').doc(user.uid).get();
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('business_name')) _businessNameController.text = data['business_name'];
        if (data.containsKey('account_number')) _accountController.text = data['account_number'];
        
        // Find matching bank
        if (data.containsKey('bank_name')) {
          final bankName = data['bank_name'];
          // Note: _banks might not be loaded yet, so we'll wait for it
          while (_banks.isEmpty && mounted) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          if (mounted) {
            setState(() {
              _selectedBank = _banks.cast<Map<String, dynamic>?>().firstWhere(
                (b) => b?['name'] == bankName, 
                orElse: () => null
              );
            });
          }
        }
      }
    }
  }

  Future<void> _linkAccount() async {
    if (_selectedBank == null || _accountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a bank/MoMo and enter number")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final subAccountCode = await _paymentService.createSubAccount(
        businessName: _businessNameController.text,
        bankCode: _selectedBank!['code'],
        accountNumber: _accountController.text.trim(),
        percentage: "0.0", 
        email: user.email ?? "agent@stayhub.app",
      );

      await _firestoreService.updateAgentProfile(user.uid, {
        'paystack_subaccount_code': subAccountCode,
        'bank_name': _selectedBank!['name'],
        'account_number': _accountController.text.trim(),
        'is_bank_verified': true,
        'business_name': _businessNameController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payout Account Linked!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Link failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Payout Setup", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())  
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO SECTION
                  _buildHeroSection(isDark),
                  
                  const SizedBox(height: 40),

                  Text("Payout Identity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)),
                  const SizedBox(height: 16),

                  // FORM CONTAINER
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      children: [
                        _buildModernField(
                          controller: _businessNameController,
                          label: "Business or Owner Name",
                          icon: Icons.person_pin_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),
                        _buildModernDropdown(isDark),
                        const SizedBox(height: 20),
                        _buildModernField(
                          controller: _accountController,
                          label: "Account / MoMo Number",
                          icon: Icons.dialpad_rounded,
                          isDark: isDark,
                          isNumber: true
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // SECURITY NOTICE
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Secure Paystack Payouts. Your rental earnings are automatically sent to this account.",
                            style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _linkAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isSubmitting 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("LINK ACCOUNT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 40),
          SizedBox(height: 16),
          Text("How you get paid", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          SizedBox(height: 8),
          Text("Connect your Bank or MoMo to receive your rental earnings automatically.", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required bool isDark,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildModernDropdown(bool isDark) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      initialValue: _selectedBank,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent),
      decoration: InputDecoration(
        labelText: "Select Bank or MoMo Network",
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
        prefixIcon: const Icon(Icons.account_balance_rounded, color: Color(0xFF2563EB), size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      items: _banks.map((bank) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: bank,
          child: Text(bank['name'], overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedBank = val),
    );
  }
}
