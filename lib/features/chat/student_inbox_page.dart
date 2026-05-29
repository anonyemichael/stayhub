import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/features/chat/chat_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StudentInboxPage extends StatefulWidget {
  const StudentInboxPage({super.key});

  @override
  State<StudentInboxPage> createState() => _StudentInboxPageState();
}

class _StudentInboxPageState extends State<StudentInboxPage> {
  String? _selectedChatId;
  String? _selectedOtherUserName;
  String? _selectedOtherUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late Stream<QuerySnapshot> _chatsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _chatsStream = FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: user.uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: isDesktop ? null : AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: isDesktop 
      ? Row(
          children: [
            SizedBox(
               width: 380,
               child: _buildChatList(user, isDesktop: true),
            ),
            VerticalDivider(width: 1, color: Colors.grey.withOpacity(0.1)),
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
                   key: ValueKey(_selectedChatId),
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
        stream: _chatsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
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
                  const Text("No messages yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
            return (bTime ?? Timestamp(0, 0)).compareTo(aTime ?? Timestamp(0, 0));
          });

          return Column(
            children: [
               Padding(
                 padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (isDesktop) ...[
                        const Text("Messages", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 20),
                     ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.toLowerCase().trim();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "Search messages...",
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                            border: InputBorder.none,
                            icon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18), 
                                    onPressed: () { 
                                      _searchController.clear(); 
                                      setState(() => _searchQuery = ""); 
                                    }
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                 ),
               ),
               Expanded(
                 child: Builder(
                   builder: (context) {
                     final filteredDocs = docs.where((doc) {
                       final chatData = doc.data() as Map<String, dynamic>;
                       final hName = (chatData['hostelName'] ?? "").toString().toLowerCase();
                       final sName = (chatData['studentName'] ?? "").toString().toLowerCase();
                       final aName = (chatData['agentName'] ?? "").toString().toLowerCase();
                       final lastMsg = (chatData['lastMessage'] ?? "").toString().toLowerCase();
                       
                       if (_searchQuery.isEmpty) return true;
                       return hName.contains(_searchQuery) || 
                              sName.contains(_searchQuery) || 
                              aName.contains(_searchQuery) ||
                              lastMsg.contains(_searchQuery);
                     }).toList();

                     if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
                       return Center(
                         child: Column(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                             const SizedBox(height: 12),
                             Text("No results for '$_searchQuery'", style: const TextStyle(color: Colors.grey)),
                           ],
                         ),
                       );
                     }

                     return ListView.builder(
                       itemCount: filteredDocs.length,
                       padding: const EdgeInsets.only(bottom: 20),
                       itemBuilder: (context, index) {
                         final chatData = filteredDocs[index].data() as Map<String, dynamic>;
                         final users = List<String>.from(chatData['users'] ?? []);
                         final otherUserId = users.firstWhere((id) => id != user.uid, orElse: () => "");
                         
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
                                if (user.displayName == chatData['studentName']) {
                                   displayTitle = chatData['hostelName'] ?? name;
                                } else {
                                   displayTitle = chatData['studentName'] ?? name;
                                }
                             }

                             final lastMsg = chatData['lastMessage'] ?? "No messages yet";
                             final hasUnread = (chatData['unreadCount_${user.uid}'] ?? 0) > 0;

                             return ListTile(
                               contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                               leading: Stack(
                                 children: [
                                   CircleAvatar(
                                     radius: 24,
                                     backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                     backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                                     child: photoUrl == null ? Text(displayTitle.isNotEmpty ? displayTitle[0].toUpperCase() : "?", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)) : null,
                                   ),
                                   StreamBuilder<DocumentSnapshot>(
                                     stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                                     builder: (context, presenceSnap) {
                                       final isOnline = (presenceSnap.hasData && presenceSnap.data!.exists) 
                                           ? (presenceSnap.data!.data() as Map<String, dynamic>)['isOnline'] == true : false;
                                       return Positioned(
                                         bottom: 0, right: 0,
                                         child: Container(
                                           width: 12, height: 12,
                                           decoration: BoxDecoration(
                                             color: isOnline ? Colors.greenAccent : Colors.grey,
                                             shape: BoxShape.circle,
                                             border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                           ),
                                         ),
                                       );
                                     }
                                   ),
                                 ],
                               ),
                               title: Text(displayTitle, style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
                               subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: hasUnread ? (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87) : Colors.grey, fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal)),
                               trailing: hasUnread 
                                 ? Container(
                                     padding: const EdgeInsets.all(6),
                                     decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                                     child: Text((chatData['unreadCount_${user.uid}'] ?? 1).toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                   ) 
                                 : null,
                               onTap: () {
                                 if (isDesktop) {
                                   setState(() {
                                     _selectedChatId = filteredDocs[index].id;
                                     _selectedOtherUserName = displayTitle;
                                     _selectedOtherUserId = otherUserId;
                                   });
                                 } else {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                                     chatId: filteredDocs[index].id,
                                     otherUserId: otherUserId,
                                     otherUserName: displayTitle,
                                   )));
                                 }
                               },
                             );
                           },
                         );
                       },
                     );
                   }
                 ),
               ),
            ],
          );
        },
    );
  }
}
