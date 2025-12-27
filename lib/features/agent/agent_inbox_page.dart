import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';

// REUSING LOGIC from StudentInboxPage but specifically for Agents if needed.
// Actually, the logic I just added to StudentInboxPage handles BOTH roles via the `displayTitle` check.
// So I can just reuse `StudentInboxPage` as a generic `InboxPage` or create this one as a wrapper.
// Let's create `AgentInboxPage` to be distinct in case we want specific Agent actions later.

class AgentInboxPage extends StatelessWidget {
  const AgentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Messages"),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('users', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_chat_unread_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No student messages", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;
          
          // Sort client-side
          docs.sort((a, b) {
             final aData = a.data() as Map<String, dynamic>;
             final bData = b.data() as Map<String, dynamic>;
             final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
             final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
             return bTime.compareTo(aTime);
          });

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final chatData = docs[index].data() as Map<String, dynamic>;
              final users = List<String>.from(chatData['users'] ?? []);
              final otherUserId = users.firstWhere((id) => id != user.uid, orElse: () => "");
              
              if (otherUserId.isEmpty) return const SizedBox.shrink();

              // For AGENT: Title should be STUDENT NAME
              // We saved 'studentName' in metadata.
              // If not there, fetch from users.
              
              final savedStudentName = chatData['studentName'] as String?;
              final hostelNameInContext = chatData['hostelName'] as String?;
              
              // If I am the agent, I want to see "Student Name (Hostel Name)" perhaps?
              // The user asked "use hostel names as agent names" (for student view).
              // For Agent view, seeing "John Doe (Sunset Hostel)" is useful.
              
              String displayTitle = "Loading...";
              String subtitlePrefix = "";

              if (savedStudentName != null) {
                displayTitle = savedStudentName;
                if (hostelNameInContext != null) {
                  subtitlePrefix = "[$hostelNameInContext] ";
                }
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                builder: (context, userSnapshot) {
                  String? photoUrl;
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                     final data = userSnapshot.data!.data() as Map<String, dynamic>;
                     if (displayTitle == "Loading...") {
                       displayTitle = data['name'] ?? "Student";
                     }
                     photoUrl = data['photoUrl'];
                  }

                  final lastMsg = chatData['lastMessage'] ?? "";
                  final time = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
                  final timeString = time != null ? DateFormat('MMM d, h:mm a').format(time) : "";

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                            chatId: docs[index].id,
                            otherUserId: otherUserId,
                            otherUserName: displayTitle,
                          )));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                    child: photoUrl == null ? const Icon(Icons.person, color: Colors.blueAccent) : null,
                                  ),
                                  // Online Indicator (Mock)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 14, height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Theme.of(context).cardColor, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayTitle, 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            maxLines: 1, 
                                            overflow: TextOverflow.ellipsis
                                          ),
                                        ),
                                        if (timeString.isNotEmpty)
                                          Text(
                                            timeString, 
                                            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "$subtitlePrefix$lastMsg", 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
