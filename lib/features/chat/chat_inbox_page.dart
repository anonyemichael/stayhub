import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/features/chat/chat_page.dart';

class ChatInboxPage extends StatefulWidget {
  final bool isAgent;
  const ChatInboxPage({super.key, this.isAgent = false});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.isAgent ? "Student Enquiries" : "Messages", 
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('users', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                // Sorting and filtering
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
                  return (bTime ?? Timestamp(0, 0)).compareTo(aTime ?? Timestamp(0, 0));
                });

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hName = (data['hostelName'] ?? "").toString().toLowerCase();
                  final sName = (data['studentName'] ?? "").toString().toLowerCase();
                  final lastMsg = (data['lastMessage'] ?? "").toString().toLowerCase();
                  return hName.contains(_searchQuery) || sName.contains(_searchQuery) || lastMsg.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemBuilder: (context, index) {
                    return _ChatInboxTile(
                      chatDoc: filteredDocs[index],
                      myUid: user.uid,
                      isAgent: widget.isAgent,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: InputDecoration(
            hintText: "Search conversations...",
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text("No messages yet", style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Start a conversation to see it here", style: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 14)),
        ],
      ),
    );
  }
}

class _ChatInboxTile extends StatelessWidget {
  final QueryDocumentSnapshot chatDoc;
  final String myUid;
  final bool isAgent;

  const _ChatInboxTile({
    required this.chatDoc,
    required this.myUid,
    required this.isAgent,
  });

  @override
  Widget build(BuildContext context) {
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final users = List<String>.from(chatData['users'] ?? []);
    final otherUserId = users.firstWhere((id) => id != myUid, orElse: () => "");
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = chatData['unreadCount_$myUid'] ?? 0;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, snapshot) {
        String name = "User";
        String? photoUrl;
        bool isOnline = false;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? "User";
          photoUrl = data['photoUrl'];
          isOnline = data['isOnline'] == true;
        }

        // Title Logic
        String displayTitle = name;
        if (!isAgent && chatData['hostelName'] != null) {
          displayTitle = chatData['hostelName'];
        } else if (isAgent && chatData['studentName'] != null) {
          displayTitle = chatData['studentName'];
        }

        final lastMsg = chatData['lastMessage'] ?? "No messages";
        final time = (chatData['lastMessageTime'] as Timestamp?)?.toDate();
        final timeStr = time != null ? _formatTime(time) : "";

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(
                chatId: chatDoc.id,
                otherUserId: otherUserId,
                otherUserName: displayTitle,
              ))),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: unreadCount > 0 
                      ? (isDark ? Colors.blueAccent.withOpacity(0.05) : Colors.blueAccent.withOpacity(0.03))
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: unreadCount > 0 ? Colors.blueAccent : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                            backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                            child: photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                          ),
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 4, right: 4,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5),
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
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: unreadCount > 0 ? Colors.blueAccent : Colors.grey[500],
                                    fontSize: 11,
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMsg,
                                  style: TextStyle(
                                    color: unreadCount > 0 
                                        ? (isDark ? Colors.white70 : Colors.black87) 
                                        : Colors.grey[500],
                                    fontSize: 13,
                                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
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
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    }
    return DateFormat('MMM d').format(date);
  }
}
