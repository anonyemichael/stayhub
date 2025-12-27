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
              "Last Updated: December 26, 2025",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            _buildParagraph(
              "At StayHub, we value your trust and are committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.",
              textColor,
            ),

            _buildSectionTitle("1. Information We Collect", textColor),
            _buildParagraph(
              "We collect information that identifies you personally mostly when you voluntarily provide it to us during registration or booking.",
              textColor,
            ),
            _buildList(
              [
                "Personal Data: Name, email address, phone number, and profile picture.",
                "Student Identity: Institution name, student ID (for verification), and gender (for room allocation).",
                "Financial Data: Transaction history. Note that we do not store sensitive card details; these are handled by our payment partners (e.g., Paystack).",
                "Device and Location Data: IP address, device type, and location data to help you find hostels near you.",
              ],
              textColor,
            ),

            _buildSectionTitle("2. How We Use Your Information", textColor),
            _buildParagraph(
              "We use the data we collect to provide and improve our services, specifically to:",
              textColor,
            ),
            _buildList(
              [
                "Process your hostel bookings and payments.",
                "Verify your student status for safety and security.",
                "Facilitate communication between you and Hostel Agents via our in-app chat.",
                "Send you booking confirmations, updates, and support messages.",
                "Improve app performance and user experience.",
              ],
              textColor,
            ),

            _buildSectionTitle("3. Sharing Your Information", textColor),
            _buildParagraph(
              "We do not sell your personal data. However, we may share identifying information with specific third parties essential to the service:",
              textColor,
            ),
            _buildList(
              [
                "Hostel Managers & Agents: When you book a request, your name, gender, and contact details are shared with the respective Agent to facilitate your move-in.",
                "Service Providers: Secure payment gateways and cloud hosting services.",
                "Legal Requirements: If required by law or to protect the rights and safety of our users.",
              ],
              textColor,
            ),

            _buildSectionTitle("4. Data Security", textColor),
            _buildParagraph(
              "We implement administrative, technical, and physical security measures to protect your personal information. While we strive to use commercially acceptable means to protect your data, no method of transmission over the Internet is 100% secure.",
              textColor,
            ),

            _buildSectionTitle("5. Your Rights", textColor),
            _buildParagraph(
              "You have the right to access, update, or delete the information we have on you. You can edit your profile directly within the app. To request full account deletion, please contact our support team or use the delete option in Settings.",
              textColor,
            ),

            _buildSectionTitle("6. Contact Us", textColor),
            _buildParagraph(
              "If you have questions about this Privacy Policy, please contact us at support@stayhub.app or via the in-app Help Center.",
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
