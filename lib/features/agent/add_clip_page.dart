import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/services/cloudinary_service.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:video_player/video_player.dart';

class AddClipPage extends StatefulWidget {
  const AddClipPage({super.key});

  @override
  State<AddClipPage> createState() => _AddClipPageState();
}

class _AddClipPageState extends State<AddClipPage> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final _captionController = TextEditingController();
  final _roomCapacityController = TextEditingController(text: "4");
  
  String? _selectedHostelName;
  String? _selectedHostelId;
  
  // Music Options
  final List<Map<String, String>> _musicTracks = [
    {'name': 'Original Audio', 'id': 'original'},
    {'name': 'Relaxing Lo-Fi', 'id': 'lofi'},
    {'name': 'Upbeat Pop', 'id': 'pop'},
    {'name': 'Afrobeat Vibes', 'id': 'afrobeat'},
  ];
  String _selectedMusicId = 'original';

  bool _isLoading = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _videoFile = file;
        _isLoading = true; // Temporary loading for initialization
      });

      _videoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {
            _isLoading = false;
            _videoController!.play();
            _videoController!.setLooping(true);
          });
        });
    }
  }

  Future<void> _postClip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a video")));
      return;
    }
    if (_selectedHostelName == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please link a hostel")));
       return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload Video
      final videoUrl = await CloudinaryService().uploadVideo(_videoFile!);
      if (videoUrl == null) throw "Video upload failed";

      // 2. Save to Firestore 'clips'
      await FirebaseFirestore.instance.collection('clips').add({
        'url': videoUrl,
        'name': _selectedHostelName, // Display Title
        'location': _selectedHostelName, // Link for "Book Now"
        'hostelId': _selectedHostelId,
        'caption': _captionController.text.trim(),
        'music': _selectedMusicId,
        'agentId': user.uid,
        'likes': [],
        'likeCount': 0,
        'commentCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'rating': 4.5, // Default or fetch from hostel
        'price': 0, // Should fetch from hostel really, but simple for now
        'capacity': int.tryParse(_roomCapacityController.text.trim()) ?? 4,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Clip posted successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Auth Required")));

    return Scaffold(
      appBar: AppBar(title: const Text("Post New Clip")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Preview / Picker
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _videoFile == null 
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("Tap to pick video from Gallery")
                        ],
                      )
                    : (_videoController != null && _videoController!.value.isInitialized)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Hostel Selector
            StreamBuilder<QuerySnapshot>(
              stream: FirestoreService().getAgentHostels(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                final hostels = snapshot.data!.docs;
                if (hostels.isEmpty) return const Text("No hostels found. Add a hostel first.");

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Link to Hostel", border: OutlineInputBorder()),
                  value: _selectedHostelId,
                  items: hostels.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(data['name'] ?? 'Unnamed'),
                      onTap: () {
                         _selectedHostelName = data['name'];
                         // Auto-populate capacity from hostel logic
                         final rawCap = data['capacity'];
                         if (rawCap != null) {
                           _roomCapacityController.text = rawCap.toString();
                         }
                      },
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedHostelId = val),
                );
              },
            ),

            const SizedBox(height: 16),

            // Number of People per Room
            TextField(
              controller: _roomCapacityController,
              decoration: const InputDecoration(
                labelText: "People per Room", 
                border: OutlineInputBorder(),
                helperText: "E.g. 4 for '4 in a room'",
                prefixIcon: Icon(Icons.people)
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Music Selector
            DropdownButtonFormField<String>(
               decoration: const InputDecoration(labelText: "Background Music", border: OutlineInputBorder(), prefixIcon: Icon(Icons.music_note)),
               value: _selectedMusicId,
               items: _musicTracks.map((track) {
                 return DropdownMenuItem(
                   value: track['id'],
                   child: Text(track['name']!),
                 );
               }).toList(),
               onChanged: (val) => setState(() => _selectedMusicId = val!),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _captionController,
              decoration: const InputDecoration(labelText: "Caption / Description", border: OutlineInputBorder()),
              maxLines: 3,
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _postClip,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Post Clip"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
