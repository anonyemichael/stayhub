import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:stayhub/data/music_library.dart';

class ItunesMusicService {
  static const String _baseUrl = 'https://itunes.apple.com/search';

  Future<List<MusicTrack>> searchMusic(String query) async {
    try {
      if (query.isEmpty) return [];

      final url = Uri.parse('$_baseUrl?term=${Uri.encodeComponent(query)}&media=music&limit=25');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        return results.map((track) {
          return MusicTrack(
            id: track['trackId'].toString(),
            title: track['trackName'] ?? 'Unknown',
            artist: track['artistName'] ?? 'Unknown',
            genre: track['primaryGenreName'] ?? 'Music',
            url: track['previewUrl'] ?? '', // This serves as the preview MP3
            coverUrl: track['artworkUrl100'],
          );
        }).where((track) => track.url.isNotEmpty).toList(); // Filter out tracks without previews
      } else {
        debugPrint("iTunes API Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("Error fetching iTunes music: $e");
      return [];
    }
  }
}
