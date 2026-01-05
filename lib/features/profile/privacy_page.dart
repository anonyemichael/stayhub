import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Privacy Policy"),
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
            
            _buildSectionTitle("1. Information We Collect", textColor),
            _buildParagraph(
              "We collect information you provide directly to us, such as when you create an account, book a hostel, or communicate with us. This includes:",
              textColor,
            ),
            _buildList(
              [
                "Name, email address, and phone number.",
                "University and Level (for student verification).",
                "Payment transaction details (processed securely via Paystack).",
              ],
              textColor,
            ),

            _buildSectionTitle("2. How We Use Your Information", textColor),
            _buildParagraph(
              "We use your information to:",
              textColor,
            ),
            _buildList(
              [
                "Facilitate hostel bookings and payments.",
                "Verify your identity as a student.",
                "Communicate with you regarding your booking status.",
                "Improve our services and prevent fraud.",
              ],
              textColor,
            ),

            _buildSectionTitle("3. Data Security", textColor),
            _buildParagraph(
              "We implement industry-standard security measures to protect your personal information. Payment data is processed by accredited third-party providers (Paystack) and is never stored on our servers.",
              textColor,
            ),

            _buildSectionTitle("4. Sharing of Information", textColor),
            _buildParagraph(
              "We share verified booking details with the specific Hostel Agent/Owner solely for the purpose of securing your accommodation. We do not sell your personal data to third parties.",
              textColor,
            ),

            _buildSectionTitle("5. Your Rights", textColor),
            _buildParagraph(
              "You have the right to access, correct, or delete your personal information. You can manage your profile settings within the StayHub app or contact us at support@stayhubgh.com.",
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
