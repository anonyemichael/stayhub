import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:stayhub/services/firestore_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;
  final bool isEmbedded;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
    this.isEmbedded = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;
  final _firestoreService = FirestoreService();
  bool _isUploading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? text, String? imageUrl}) async {
    final msgText = text?.trim() ?? "";
    if (msgText.isEmpty && imageUrl == null) return;

    if (msgText.isNotEmpty) {
      _messageController.clear();
    }

    final user = _auth.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    
    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'text': msgText,
      'imageUrl': imageUrl,
      'type': imageUrl != null ? 'image' : 'text',
      'senderId': user.uid,
      'senderName': user.displayName ?? 'User',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Update last message and unread count for recipient
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    batch.update(chatRef, {
      'lastMessage': imageUrl != null ? '📷 Image' : msgText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_${widget.otherUserId}': FieldValue.increment(1),
      'typing_${user.uid}': false,
    });

    await batch.commit();

    // Send Real-time Notification
    await _firestoreService.sendChatNotification(
      recipientId: widget.otherUserId,
      senderName: user.displayName ?? 'Someone',
      messageText: imageUrl != null ? 'Sent an image' : msgText,
      chatId: widget.chatId,
    );
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      
      XFile xFile = pickedFile;
      String? uploadedUrl = await CloudinaryService().uploadProfilePicture(xFile);

      setState(() => _isUploading = false);

      if (uploadedUrl != null) {
        _sendMessage(imageUrl: uploadedUrl);
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to upload image")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Error: Not Logged In")));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Row(
          children: [
            _buildOtherUserAvatar(widget.otherUserId, isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildPresenceStatus(widget.otherUserId),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {},
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                _markMessagesAsRead(docs, user.uid);

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == user.uid;
                    final time = (data['timestamp'] as Timestamp?)?.toDate();
                    
                    bool showDateHeader = false;
                    if (index == docs.length - 1) {
                      showDateHeader = true;
                    } else {
                      final prevData = docs[index + 1].data() as Map<String, dynamic>;
                      final prevTime = (prevData['timestamp'] as Timestamp?)?.toDate();
                      if (time != null && prevTime != null && !_isSameDay(time, prevTime)) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateHeader && time != null)
                          _buildDateHeader(time),
                        _buildMessageBubble(docs[index], isMe, isDark, primaryColor),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(isDark, primaryColor, user.uid),
        ],
      ),
    );
  }

  Widget _buildOtherUserAvatar(String userId, bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        String? photoUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          photoUrl = (snapshot.data!.data() as Map<String, dynamic>)['photoUrl'];
        }
        return CircleAvatar(
          radius: 18,
          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
          child: photoUrl == null ? const Icon(Icons.person, size: 20) : null,
        );
      },
    );
  }

  Widget _buildPresenceStatus(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        bool isOnline = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isOnline = (snapshot.data!.data() as Map<String, dynamic>)['isOnline'] == true;
        }
        return Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isOnline ? "Online" : "Offline",
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_rounded, size: 40, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          const Text(
            "Start the conversation",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Messages are end-to-end encrypted",
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(QueryDocumentSnapshot doc, bool isMe, bool isDark, Color primaryColor) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'text';
    final text = data['text'] ?? '';
    final imageUrl = data['imageUrl'];
    final time = (data['timestamp'] as Timestamp?)?.toDate();
    final isRead = data['isRead'] == true;
    final isDeleted = data['isDeleted'] == true;

    if (isDeleted) {
       return Align(
         alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
         child: Container(
           margin: const EdgeInsets.symmetric(vertical: 4),
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
           decoration: BoxDecoration(
             color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
             borderRadius: BorderRadius.circular(15),
           ),
           child: Text(
             "Message deleted",
             style: TextStyle(color: Colors.grey[500], fontSize: 13, fontStyle: FontStyle.italic),
           ),
         ),
       );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showOptions(context, doc.reference, isMe),
            child: Container(
              margin: const EdgeInsets.only(top: 4, bottom: 2),
              padding: type == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe 
                    ? primaryColor 
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                gradient: isMe 
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'image' && imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        placeholder: (context, url) => Container(height: 200, width: 200, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    )
                  else
                    Text(
                      text,
                      style: TextStyle(
                        color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(time),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: isRead ? Colors.blueAccent : Colors.grey[400],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color primaryColor, String uid) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _pickAndSendImage,
            icon: Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 28),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                    'typing_$uid': val.isNotEmpty,
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(text: _messageController.text),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _markMessagesAsRead(List<QueryDocumentSnapshot> docs, String myUid) {
    final batch = FirebaseFirestore.instance.batch();
    bool hasUpdates = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] != myUid && data['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      batch.commit();
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'unreadCount_$myUid': 0,
      });
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return "Today";
    if (dateToCheck == yesterday) return "Yesterday";
    return DateFormat('MMMM d, y').format(date);
  }

  void _showOptions(BuildContext context, DocumentReference ref, bool isMe) {
    if (!isMe) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              ),
              title: const Text("Delete Message", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                ref.update({'isDeleted': true});
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
