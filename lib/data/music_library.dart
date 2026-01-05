// CENTRAL MUSIC LIBRARY
// Stores all available background tracks for Clips
// Using Copyright-Free / Public Domain Placeholders for Demo

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String genre;
  final String url;
  final String? coverUrl;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.url,
    this.coverUrl,
  });
}

class MusicLibrary {
  static const List<MusicTrack> allTracks = [
    // --- AMAPIANO ---
    MusicTrack(
      id: 'amapiano_chill',
      title: 'Amapiano Sunset',
      artist: 'StayHub Vibes',
      genre: 'Amapiano',
      url: 'https://codeskulptor-demos.commondatastorage.googleapis.com/lisztonian/pachelbel.mp3', // Placeholder (Piano)
    ),
    MusicTrack(
      id: 'amapiano_log',
      title: 'Log Drum Heavy',
      artist: 'StayHub Vibes',
      genre: 'Amapiano',
      url: 'https://commondatastorage.googleapis.com/codeskulptor-assets/Epoq-Lepidoptera.ogg', // Placeholder (Rhythm)
    ),

    // --- AFROBEAT ---
    MusicTrack(
      id: 'afrobeat_classic',
      title: 'Afrobeat Classic',
      artist: 'StayHub Vibes',
      genre: 'Afrobeat',
      url: 'https://codeskulptor-demos.commondatastorage.googleapis.com/pang/paza-moduless.mp3', // Placeholder (Upbeat)
    ),
     MusicTrack(
      id: 'afrobeat_party',
      title: 'Accra Night',
      artist: 'StayHub Vibes',
      genre: 'Afrobeat',
      url: 'https://codeskulptor-demos.commondatastorage.googleapis.com/GalaxyInvaders/theme_01.mp3', // Placeholder (Synth)
    ),

    // --- GOSPEL ---
    MusicTrack(
      id: 'gospel_praise',
      title: 'Sunday Praise',
      artist: 'Choir',
      genre: 'Gospel',
      url: 'https://commondatastorage.googleapis.com/codeskulptor-demos/riceracer_assets/music/win.ogg', // Placeholder (Triumphant)
    ),

    // --- HIP HOP / TRAP ---
    MusicTrack(
      id: 'trap_drill',
      title: 'Kumasi Drill',
      artist: 'Asakaa',
      genre: 'Hip Hop',
      url: 'https://commondatastorage.googleapis.com/codeskulptor-assets/music/race_start.ogg', // Placeholder
    ),
    
    // --- LO-FI / CHILL ---
    MusicTrack(
      id: 'lofi_study',
      title: 'Late Night Study',
      artist: 'Lofi Girl',
      genre: 'Chill',
      url: 'https://codeskulptor-demos.commondatastorage.googleapis.com/GalaxyInvaders/bonus.mp3', // Placeholder
    ),

    // --- NEW ADDITIONS ---
    MusicTrack(
      id: 'pop_upbeat',
      title: 'Summer Vibes',
      artist: 'StayHub Pop',
      genre: 'Pop',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    MusicTrack(
      id: 'electronic_dance',
      title: 'Night Club',
      artist: 'DJ Hub',
      genre: 'Electronic',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
    MusicTrack(
      id: 'acoustic_morning',
      title: 'Morning Coffee',
      artist: 'Acoustic Soul',
      genre: 'Acoustic',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    ),
    MusicTrack(
      id: 'jazz_smooth',
      title: 'Smooth Jazz',
      artist: 'The Sax Guy',
      genre: 'Jazz',
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
    ),
  ];

  static MusicTrack? getTrackById(String id) {
    try {
      return allTracks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
