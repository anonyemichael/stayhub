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
        title: const Text("Terms of Service"),
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
              "Last Updated: December 26, 2025",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            _buildParagraph(
              "Welcome to StayHub! By using our platform, you agree to these legal terms. Please read them carefully as they govern your booking experience.",
              textColor,
            ),
            
            _buildSectionTitle("1. Scope of Service", textColor),
            _buildParagraph(
              "StayHub acts as an intermediary platform connecting students with hostel managers/agents. We do not own, manage, or operate any of the properties listed. Your tenancy agreement is directly between you and the Hostel Manager.",
              textColor,
            ),

            _buildSectionTitle("2. Bookings & Payments", textColor),
            _buildParagraph(
              "All booking requests are subject to approval by the respective Agent. A booking is only 'Confirmed' once the Agent accepts it or payment is verified.",
              textColor,
            ),
            _buildList(
              [
                "Currency: All transactions are in Ghana Cedis (GHS).",
                "Platform Fees: A small service fee may be included in payments to support the app maintenance.",
                "Payment Security: Payments are processed by licensed third-party providers (e.g., Paystack). Safety is our priority.",
              ],
              textColor
            ),

            _buildSectionTitle("3. Cancellations & Refunds", textColor),
            _buildParagraph(
              "We understand plans change. To ensure fair compensation for agents and timely processing, our policy is strictly enforced:",
              textColor,
            ),
            _buildList(
              [
                "24-Hour Automatic Refund: You are entitled to a full refund if you cancel within 24 hours of making the payment. This can be done instantly within the app.",
                "Non-Refundable Period: After 24 hours, funds are settled to the Hostel Manager's bank account. Cancellations after this window are NOT eligible for automated refunds via StayHub and must be negotiated directly with the Agent.",
                "Fraud Protection: If a hostel is found to be non-existent or fraudulent, StayHub will intervene to secure a full refund regardless of the timeline.",
              ],
              textColor
            ),

            _buildSectionTitle("4. User Conduct", textColor),
            _buildList(
              [
                "Honesty: You agree to provide accurate information (Name, Student ID).",
                "Respect: Harassment of Agents or other students via our chat system is strictly prohibited.",
                "No Spam: You may not make fake booking requests.",
              ],
              textColor
            ),

            _buildSectionTitle("5. Liability Disclaimer", textColor),
            _buildParagraph(
              "StayHub verifies agents to the best of our ability, but we are not liable for disputes arising from tenancy rules, property damage, or interpersonal conflicts at the hostel. We recommend visiting the hostel in person before making full rent payment if possible.",
              textColor,
            ),

            _buildSectionTitle("6. Account Termination & Deletion", textColor),
            _buildParagraph(
              "We reserve the right to suspend accounts that violate these terms.",
              textColor,
            ),
            _buildParagraph(
              "You may delete your account at any time via the Settings page. Upon deletion, your personal data is removed from our live systems, though transaction records may be kept for legal compliance.",
              textColor,
            ),

            const SizedBox(height: 40),

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
          color: color?.withValues(alpha: 0.8),
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
                    color: color?.withValues(alpha: 0.8),
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
