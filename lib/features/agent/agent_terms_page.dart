import 'package:flutter/material.dart';

class AgentTermsPage extends StatelessWidget {
  const AgentTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Partner Terms", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
            _buildHeader("Master Service Agreement", isDark),
            _buildSection(
              "1. Property Accuracy", 
              "As an Agent, you warrant that all property details, pricing, and availability uploaded to StayHub are 100% accurate. Misleading information (e.g., incorrect pricing or fake amenities) is grounds for immediate account suspension.",
              isDark
            ),
            _buildSection(
              "2. Content Ownership", 
              "You retain ownership of the videos uploaded to the Creator Studio. However, by uploading, you grant StayHub a non-exclusive, worldwide license to use these clips for marketing the platform and your property.",
              isDark
            ),
            _buildSection(
              "3. Commission & Payouts", 
              "StayHub deducts a platform service fee from every booking. Payouts are initiated within 24-48 hours of booking confirmation. You are responsible for providing valid and accurate banking details.",
              isDark
            ),
            _buildSection(
              "4. Student Relations", 
              "Agents are expected to maintain professional conduct with students. Discriminatory behavior or harassment will result in a permanent ban and potential legal reporting.",
              isDark
            ),
            _buildSection(
              "5. Liability", 
              "StayHub is a platform that connects students with agents. We are not responsible for the physical condition of the property or disputes between students and agents beyond the digital transaction.",
              isDark
            ),
            _buildSection(
              "6. Account Integrity", 
              "You are responsible for maintaining the security of your account credentials. Any fraudulent activity detected on your account will result in a freeze on your wallet balance pending investigation.",
              isDark
            ),
            const SizedBox(height: 40),
            Center(child: Text("Acceptance of these terms constitutes a legal agreement.", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold))),
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
