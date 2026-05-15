import 'package:flutter/material.dart';

class AgentPrivacyPage extends StatelessWidget {
  const AgentPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Business Privacy", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Partner Data Protection", isDark),
            _buildSection(
              "Data Collection", 
              "As a StayHub Business Partner, we collect specific information to facilitate your operations, including: Business Name, ID Verification, Banking/Payout details, and Property Metadata.",
              isDark
            ),
            _buildSection(
              "Media & Intellectual Property", 
              "Videos and images uploaded to the Creator Studio are stored on secure cloud servers (Cloudinary). We collect performance metrics (views/likes) to optimize your content reach.",
              isDark
            ),
            _buildSection(
              "Student Interaction", 
              "When a student interacts with your listing, you gain access to their necessary booking data. You are legally bound to handle this data within StayHub's secure environment and are prohibited from exporting student data for external marketing.",
              isDark
            ),
            _buildSection(
              "Financial Security", 
              "Banking information is encrypted and used solely for payouts. We do not store full payment card details on our local servers; all transactions are processed via secure payment gateways.",
              isDark
            ),
            _buildSection(
              "Data Retention", 
              "Business records are maintained for as long as your account is active. Upon termination, certain records may be kept for legal and financial audit purposes for up to 7 years.",
              isDark
            ),
            const SizedBox(height: 40),
            Center(child: Text("Last Updated: May 2026", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
