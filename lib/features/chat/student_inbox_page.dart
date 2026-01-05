import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';

class StudentInboxPage extends StatefulWidget {
  const StudentInboxPage({super.key});

  @override
  State<StudentInboxPage> createState() => _StudentInboxPageState();
}

class _StudentInboxPageState extends State<StudentInboxPage> {
  String? _selectedChatId;
  String? _selectedOtherUserName;
  String? _selectedOtherUserId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text("Messages"),
        elevation: 0,
      ),
      body: isDesktop 
      ? Row(
          children: [
            // Sidebar
            SizedBox(
               width: 380,
               child: _buildChatList(user, isDesktop: true),
            ),
            VerticalDivider(width: 1, color: Colors.grey.withOpacity(0.1)),
            // Main Content
            Expanded(
               child: _selectedChatId == null
               ? Center(
                   child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.withOpacity(0.2)),
                         const SizedBox(height: 20),
                         Text("Select a conversation", style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 18)),
                      ],
                   )
               )
               : ChatPage(
                   key: ValueKey(_selectedChatId), // Force rebuild on change
                   chatId: _selectedChatId!,
                   otherUserName: _selectedOtherUserName ?? "Chat",
                   otherUserId: _selectedOtherUserId ?? "",
                   isEmbedded: true,
                 )
            )
          ],
        )
      : _buildChatList(user),
    );
  }

  Widget _buildChatList(User user, {bool isDesktop = false}) {
    return StreamBuilder<QuerySnapshot>(
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

          // Client-side sorting
          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime); 
          });

          return Column(
            children: [
               if (isDesktop) 
                  Container(
                     padding: const EdgeInsets.all(20),
                     alignment: Alignment.centerLeft,
                     child: const Text("Messages", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
               Expanded(
                 child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
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
                        
                        String displayTitle = name;
                        if (chatData['hostelName'] != null) {
                           final savedStudentName = chatData['studentName'] as String?;
                           if (user.displayName == savedStudentName) {
                              displayTitle = chatData['hostelName'] ?? name;
                           } else {
                              displayTitle = savedStudentName ?? name;
                           }
                        }

                        final lastMsg = chatData['lastMessage'] ?? "";
                        final time = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
                        final timeString = time != null ? DateFormat('h:mm a').format(time) : "";
                        
                        final isSelected = _selectedChatId == docs[index].id;

                        return Material(
                          color: (isDesktop && isSelected) ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (isDesktop) {
                                 setState(() {
                                    _selectedChatId = docs[index].id;
                                    _selectedOtherUserName = displayTitle;
                                    _selectedOtherUserId = otherUserId;
                                 });
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                                  chatId: docs[index].id,
                                  otherUserId: otherUserId,
                                  otherUserName: displayTitle,
                                )));
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                    child: photoUrl == null ? const Icon(Icons.person, color: Colors.blueAccent, size: 20) : null,
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
                                                style: TextStyle(
                                                   fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                                                   fontSize: 16,
                                                   color: isSelected ? Theme.of(context).primaryColor : null,
                                                ),
                                                maxLines: 1, 
                                                overflow: TextOverflow.ellipsis
                                              ),
                                            ),
                                            if (timeString.isNotEmpty)
                                              Text(
                                                timeString, 
                                                style: TextStyle(color: Colors.grey[400], fontSize: 12)
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lastMsg, 
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
                        );
                      },
                    );
                  },
                ),
               ),
            ],
          );
        },
    );
  }
}
