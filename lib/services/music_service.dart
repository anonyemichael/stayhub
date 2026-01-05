import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stayhub/data/music_library.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/itunes_music_service.dart';

class MusicService {
  final _firestore = FirestoreService();
  final _itunes = ItunesMusicService();

  // 1. Fetch Trending / Saved Music from Firestore
  Future<List<MusicTrack>> fetchTrendingMusic() async {
    final snapshot = await _firestore.getMusic().first;
    if (snapshot.docs.isNotEmpty) {
      return _mapDocsToTracks(snapshot.docs);
    }
    // Fallback: If DB empty, just return some default search for "Afrobeat"
    return await searchMusic("Afrobeat");
  }

  // 2. Search Music via iTunes API
  Future<List<MusicTrack>> searchMusic(String query) async {
    if (query.isEmpty) return fetchTrendingMusic();
    
    // API Call
    final tracks = await _itunes.searchMusic(query);
    
    // Optional: Cache these results to Firestore so they become "Trending" over time
    // For now, we won't spam the DB, just return results
    return tracks;
  }
  
  // 3. Helper to save a Selected Track to Firestore
  Future<void> saveTrackToDB(MusicTrack track) async {
    await _firestore.seedMusic([{
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'genre': track.genre,
      'url': track.url,
      'coverUrl': track.coverUrl,
    }]);
  }

  List<MusicTrack> _mapDocsToTracks(List<QueryDocumentSnapshot> docs) {
    return docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return MusicTrack(
        id: data['id'] ?? d.id,
        title: data['title'] ?? 'Unknown',
        artist: data['artist'] ?? 'Unknown',
        genre: data['genre'] ?? 'Other',
        url: data['url'] ?? '',
        coverUrl: data['coverUrl'],
      );
    }).toList();
  }
}
