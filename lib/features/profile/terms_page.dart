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
              "Last Updated: October 2023",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle("1. Agreement to Terms", textColor),
            _buildParagraph(
              "By accessing or using StayHub, you agree to be bound by these Terms of Service. If you disagree with any part of the terms, then you may not access the Service.",
              textColor,
            ),
            
            _buildSectionTitle("2. User Accounts", textColor),
            _buildParagraph(
              "When you create an account with us, you must provide information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our Service.",
              textColor,
            ),
            
            _buildSectionTitle("3. Bookings & Payments", textColor),
            _buildParagraph(
              "All bookings are subject to availability and confirmation by the hostel. We facilitate the booking process but are not responsible for the condition of the hostel itself. Payments are processed securely through our third-party providers.",
              textColor,
            ),

            _buildSectionTitle("4. Content", textColor),
            _buildParagraph(
              "Our Service allows you to post, link, store, share and otherwise make available certain information, text, graphics, videos, or other material ('Content'). You are responsible for the Content that you post to the Service, including its legality, reliability, and appropriateness.",
              textColor,
            ),

            _buildSectionTitle("5. Termination", textColor),
            _buildParagraph(
              "We may terminate or suspend access to our Service immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.",
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
}
