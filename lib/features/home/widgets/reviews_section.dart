import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReviewsSection extends StatefulWidget {
  final String hostelId;

  const ReviewsSection({super.key, required this.hostelId});

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  final TextEditingController _reviewController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _rating = 5.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Reviews", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // Review Input
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    const Text("Rate:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ...List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _rating = index + 1.0),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 30, 
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reviewController,
                  decoration: InputDecoration(
                    hintText: "Write a review...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Post Review", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Reviews List
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('hostels')
              .doc(widget.hostelId)
              .collection('reviews')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(child: Text("No reviews yet. Be the first!", style: TextStyle(color: Colors.grey)));
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                 final data = docs[index].data() as Map<String, dynamic>;
                 final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                 
                 return Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: Theme.of(context).cardColor,
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: Colors.grey.withOpacity(0.1)),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Expanded(
                             child: Text(
                               data['userName'] ?? 'Anonymous', 
                               style: const TextStyle(fontWeight: FontWeight.bold),
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                           const SizedBox(width: 8),
                           Text(timeago.format(date), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                         ],
                       ),
                       const SizedBox(height: 6),
                       Row(
                         children: List.generate(5, (i) => Icon(
                           i < (data['rating'] ?? 0) ? Icons.star : Icons.star_border,
                           size: 14, color: Colors.orange
                         )),
                       ),
                       const SizedBox(height: 8),
                       Text(data['text'] ?? ''),
                     ],
                   ),
                 );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _submitReview() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login to review")));
      return;
    }
    
    if (_reviewController.text.trim().isEmpty) return;

    final reviewData = {
      'userId': user.uid,
      'userName': user.displayName ?? 'Student',
      'userImage': user.photoURL,
      'text': _reviewController.text.trim(),
      'rating': _rating,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('reviews')
          .add(reviewData);
          
      _reviewController.clear();
      if (mounted) {
         FocusScope.of(context).unfocus();
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review Posted!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Error posting review: $e");
    }
  }
}
