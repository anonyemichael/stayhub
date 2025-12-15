import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';

class StudentInboxPage extends StatelessWidget {
  const StudentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No messages yet", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          // Client-side sorting to avoid missing index error
          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime); // Descending
          });

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chatData = docs[index].data() as Map<String, dynamic>;
              final users = List<String>.from(chatData['users'] ?? []);
              final otherUserId = users.firstWhere((id) => id != user.uid, orElse: () => "");
              
              if (otherUserId.isEmpty) return const SizedBox.shrink();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  
                  String name = "User";
                  String? photoUrl;

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    name = userData['name'] ?? "User";
                    photoUrl = userData['photoUrl'];
                  }

                  // Context override:
                  // If I am the student, I want to see "Hostel Name" (if available) instead of "Agent Name".
                  // If I am the agent, I want to see "Student Name".
                  
                  // Simple heuristic: If chat has 'hostelName' and I am NOT the agent (or logic: just show hostel name if it's not my name?) 
                  // Better: The 'users' array has 2 IDs. We found 'otherUserId'.
                  
                  // If chatData has 'hostelName', let's use it if we are the student?
                  // We don't easily know strictly "who is who" without roles, but we can assume:
                  // If the 'other user' is the Agent (receives money etc), the student sees Hostel Name.
                  // But easier: check if chatData['hostelName'] is present. 
                  // If present, verify if we should show it.
                  
                  String displayTitle = name;
                  if (chatData['hostelName'] != null) {
                     // We need a way to know if 'otherUserId' is the Agent. 
                     // Usually, the one creating the hostel is the agent.
                     // Let's assume for this specific requirement: Student sees Hostel Name.
                     // The student won't have the same name as the hostel usually.
                     // So we can use hostelName as the primary label.
                     
                     // Wait, if I am the Agent, I want to see the *Student Name*, not the Hostel Name (which I own).
                     // Ideally, chat metadata should have 'studentId' and 'agentId'.
                     // We didn't store those explicitly as "roles" yet, just 'users'.
                     // But we added 'studentName' to metadata in BookingsPage.
                     
                     final savedStudentName = chatData['studentName'] as String?;
                     
                     if (user!.displayName == savedStudentName) {
                        // I am the student. Show Hostel Name.
                        displayTitle = chatData['hostelName'] ?? name;
                     } else {
                        // I am the agent (or someone else). Show Student Name.
                        displayTitle = savedStudentName ?? name;
                     }
                  }

                  final lastMsg = chatData['lastMessage'] ?? "";
                  final time = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
                  final timeString = time != null ? DateFormat('MMM d, h:mm a').format(time) : "";

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(timeString, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                        chatId: docs[index].id,
                        otherUserId: otherUserId,
                        otherUserName: displayTitle,
                      )));
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
