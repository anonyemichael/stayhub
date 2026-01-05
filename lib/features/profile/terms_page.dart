import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Terms & Conditions"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Last Updated: December 30, 2025",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            const Text("IMPORTANT: PLEASE READ THESE TERMS CAREFULLY. BY USING STAYHUB, YOU AGREE TO BE BOUND BY THEM.",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
            ),

            _buildSectionTitle("1. Acceptance of Terms", textColor),
            _buildParagraph(
              "By accessing or using the StayHub mobile application or website (\"Platform\"), you agree to be bound by these Terms and Conditions (\"Terms\"). If you do not agree, you must immediately cease using the Service.",
              textColor,
            ),

            _buildSectionTitle("2. Intermediary Role", textColor),
            _buildParagraph(
              "StayHub is strictly a technology platform that connects students with independent hostel agents and owners. We are NOT a real estate agency, landlord, or property manager.",
              textColor,
            ),
            _buildList([
              "We do not own, manage, or inspect properties.",
              "We verify Agent identities but do not guarantee property suitability.",
              "Accommodation agreements are solely between the Student and the Agent."
            ], textColor),

            _buildSectionTitle("3. User Responsibilities", textColor),
            _buildParagraph(
              "CRITICAL: YOU ARE SOLELY RESPONSIBLE FOR VERIFYING THE PROPERTY.",
              textColor,
            ),
            _buildList([
              "Physical Inspection: You are strongly advised to visit properties BEFORE payment.",
              "\"As Is\": Media is for reference only; properties are accepted 'as is'.",
              "Fraud Prevention: Conduct all transactions within the app."
            ], textColor),

            _buildSectionTitle("4. Payments & Refunds", textColor),
            _buildList([
              "No Cancellation: Once payment is made, it is FINAL and NON-REFUNDABLE via the Platform.",
              "Refund Disputes: These must be directed to the Agent/Landlord directly.",
              "Service Fees: Platform fees are non-refundable."
            ], textColor),

            _buildSectionTitle("5. Limitation of Liability", textColor),
            _buildParagraph(
              "StayHub is not liable for injuries, thefts, property damage, or disputes occurring at hostels. Our liability is limited to the Platform Fee paid for the specific transaction.",
              textColor,
            ),

            _buildSectionTitle("6. Contact", textColor),
            _buildParagraph(
              "For legal notices, please contact us at support@stayhubgh.com.",
              textColor,
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: color?.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildList(List<String> items, Color? color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5, left: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("• ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    color: color?.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
