class Song {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? albumArtUrl;
  final String language;   // 'bollywood' | 'english' | 'international'
  final String decade;     // '70s' | '80s' | '90s' | '00s' | '10s' | '20s'
  final List<String> tags;
  final int silenceOffset; // seconds to skip at start (silence detection)

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.albumArtUrl,
    required this.language,
    required this.decade,
    required this.tags,
    required this.silenceOffset,
  });

  factory Song.fromMap(String id, Map<String, dynamic> d) {
    return Song(
      id: id,
      title: d['title'] ?? '',
      artist: d['artist'] ?? '',
      audioUrl: d['audioUrl'] ?? '',
      albumArtUrl: d['albumArtUrl'],
      language: d['language'] ?? 'english',
      decade: d['decade'] ?? '20s',
      tags: List<String>.from(d['tags'] ?? []),
      silenceOffset: d['silenceOffset'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'artist': artist,
    'audioUrl': audioUrl,
    'albumArtUrl': albumArtUrl,
    'language': language,
    'decade': decade,
    'tags': tags,
    'silenceOffset': silenceOffset,
  };

  // Normalised title for fuzzy matching
  String get normalizedTitle =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();

  String get normalizedArtist =>
      artist.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();
}