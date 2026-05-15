import 'package:flutter/material.dart';
import 'package:stayhub/features/chat/chat_inbox_page.dart';

class AgentInboxPage extends StatelessWidget {
  const AgentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatInboxPage(isAgent: true);
  }
}
