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
              "Last Updated: October 2023",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle("1. Introduction", textColor),
            _buildParagraph(
              "Welcome to StayHub. We are committed to protecting your personal information and your right to privacy. If you have any questions or concerns about our policy, or our practices with regards to your personal information, please contact us.",
              textColor,
            ),
            _buildSectionTitle("2. Information We Collect", textColor),
            _buildParagraph(
              "We collect personal information that you voluntarily provide to us when you register on the App, express an interest in obtaining information about us or our products and services, when you participate in activities on the App or otherwise when you contact us.",
              textColor,
            ),
            _buildList(
              [
                "Name and Contact Data (Email, Phone Number)",
                "Credentials (Passwords, Security information)",
                "Payment Data (Processed securely by our payment processors)",
              ],
              textColor,
            ),
            _buildSectionTitle("3. How We Use Your Information", textColor),
            _buildParagraph(
              "We use personal information collected via our App for a variety of business purposes described below. We process your personal information for these purposes in reliance on our legitimate business interests, in order to enter into or perform a contract with you, with your consent, and/or for compliance with our legal obligations.",
              textColor,
            ),
            _buildList(
              [
                "To facilitate account creation and logon process.",
                "To send you marketing and promotional communications.",
                "To fulfill and manage your orders and bookings.",
              ],
              textColor,
            ),
            _buildSectionTitle("4. Sharing Your Information", textColor),
            _buildParagraph(
              "We only share information with your consent, to comply with laws, to provide you with services, to protect your rights, or to fulfill business obligations.",
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
