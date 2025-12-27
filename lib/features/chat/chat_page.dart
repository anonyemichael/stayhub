import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/services/cloudinary_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isUploading = false;

  void _sendMessage({String? text, String? imageUrl}) async {
    final msgText = text?.trim() ?? "";
    if (msgText.isEmpty && imageUrl == null) return;

    if (msgText.isNotEmpty) {
      _messageController.clear();
    }

    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'text': msgText,
      'imageUrl': imageUrl,
      'type': imageUrl != null ? 'image' : 'text',
      'senderId': user.uid,
      'senderName': user.displayName ?? 'User',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update last message
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'users': [user.uid, widget.otherUserId],
      'lastMessage': imageUrl != null ? '📷 Image' : msgText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      
      File file = File(pickedFile.path);
      String? uploadedUrl = await CloudinaryService().uploadProfilePicture(file);

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

    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              title: Text(widget.otherUserName, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
              elevation: 0,
              iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Pattern (Optional)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network("https://www.transparenttextures.com/patterns/cubes.png", repeat: ImageRepeat.repeat),
            ),
          ),
          
          Column(
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
                    if (docs.isEmpty) {
                         return Center(
                             child: Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Icon(Icons.mark_chat_read_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.3)),
                                 const SizedBox(height: 10),
                                 Text("Say Hello! 👋", style: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 16)),
                               ],
                             )
                         );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 100, bottom: 20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == user.uid;
                        final time = (data['timestamp'] as Timestamp?)?.toDate();
                        final type = data['type'] ?? 'text';
                        final imageUrl = data['imageUrl'];
                        
                        // Date Logic
                        bool showDateHeader = false;
                        if (index == docs.length - 1) {
                          showDateHeader = true; // Always show for oldest message
                        } else {
                          final prevData = docs[index + 1].data() as Map<String, dynamic>; // Older message
                          final prevTime = (prevData['timestamp'] as Timestamp?)?.toDate();
                          if (time != null && prevTime != null && !_isSameDay(time, prevTime)) {
                            showDateHeader = true;
                          }
                        }

                        // Grouping Logic (for bubble shape)
                        bool isFirstInSequence = false; // Physically top of group (Oldest of sequence)
                        bool isLastInSequence = false; // Physically bottom of group (Newest of sequence) (Index 0 is newest)
                        
                        // Check Next (Index + 1, Older) -> Determine if I am "First"
                        if (index == docs.length - 1) {
                           isFirstInSequence = true;
                        } else {
                           final prevData = docs[index + 1].data() as Map<String, dynamic>;
                           if (prevData['senderId'] != data['senderId']) isFirstInSequence = true;
                           if (showDateHeader) isFirstInSequence = true; // New day breaks sequence
                        }

                        // Check Previous (Index - 1, Newer) -> Determine if I am "Last"
                        if (index == 0) {
                           isLastInSequence = true;
                        } else {
                           final nextData = docs[index - 1].data() as Map<String, dynamic>;
                           if (nextData['senderId'] != data['senderId']) isLastInSequence = true;
                           // Note: Date header logic for next message doesn't affect MY bottom shape, 
                           // but if next message HAS a date header, it visually breaks anyway.
                           // Actually, if index-1 has a date header, it means index-1 is start of new day.
                           // So index is end of old day.
                           final nextTime = (nextData['timestamp'] as Timestamp?)?.toDate();
                           if (nextTime != null && time != null && !_isSameDay(nextTime, time)) isLastInSequence = true; 
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDateHeader && time != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  _formatDate(time),
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),

                            Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Avatar for Other User (Only show at bottom of sequence)
                                  if (!isMe)
                                    Container(
                                      width: 28, 
                                      margin: const EdgeInsets.only(right: 8),
                                      child: isLastInSequence 
                                        ? const CircleAvatar(radius: 14, backgroundImage: AssetImage('assets/placeholder_avatar.png'), child: Icon(Icons.person, size: 16)) // Replace with user image if available passing it down
                                        : const SizedBox.shrink(),
                                    ),
                                  
                                  Flexible(
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: isLastInSequence ? 12 : 2),
                                      padding: type == 'text' ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) : const EdgeInsets.all(4),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
                                      decoration: BoxDecoration(
                                        gradient: isMe 
                                            ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]) 
                                            : LinearGradient(colors: isDark ? [const Color(0xFF2D3748), const Color(0xFF2D3748)] : [Colors.white, Colors.white]),
                                        color: isMe ? null : (isDark ? const Color(0xFF2D3748) : Colors.white),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft: isMe ? const Radius.circular(18) : (isLastInSequence ? const Radius.circular(4) : const Radius.circular(18)),
                                          bottomRight: isMe ? (isLastInSequence ? const Radius.circular(4) : const Radius.circular(18)) : const Radius.circular(18),
                                        ),
                                        boxShadow: [
                                          if (!isMe && isDark) const BoxShadow(color: Colors.transparent) // No shadow for dark mode bubbles
                                          else BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (type == 'image' && imageUrl != null)
                                            GestureDetector(
                                              onTap: () => _showFullImage(context, imageUrl),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(14),
                                                child: Hero(
                                                  tag: imageUrl,
                                                  child: CachedNetworkImage(
                                                    imageUrl: imageUrl,
                                                    placeholder: (context, url) => Container(height: 150, width: 150, color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
                                                    errorWidget: (context, url, err) => const Icon(Icons.broken_image),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Text(
                                              data['text'] ?? '',
                                              style: TextStyle(
                                                  color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                                  fontSize: 16,
                                              ),
                                            ),
                                          if (time != null && isLastInSequence) ...[
                                            const SizedBox(height: 4),
                                            Align(
                                              alignment: Alignment.bottomRight,
                                              child: Text(
                                                DateFormat('h:mm a').format(time),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: LinearProgressIndicator(borderRadius: BorderRadius.circular(10), backgroundColor: Colors.grey.withValues(alpha: 0.2)),
                ),
              
              // INPUT AREA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], shape: BoxShape.circle),
                        child: IconButton(
                          onPressed: _pickAndSendImage,
                          icon: Icon(Icons.add_photo_alternate_rounded, color: isDark ? Colors.white70 : Colors.grey[600], size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            isDense: true,
                          ),
                          onSubmitted: (val) => _sendMessage(text: val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _sendMessage(text: _messageController.text),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return "Today";
    } else if (dateToCheck == yesterday) {
      return "Yesterday";
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: CachedNetworkImage(imageUrl: url)),
    )));
  }
}
