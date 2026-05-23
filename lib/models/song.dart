class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String audioUrl;
  final String albumArtUrl;
  final String genre;
  final String language;
  final String decade;
  final String difficulty;   // 'easy' | 'medium' | 'hard' | 'hardcore'
  final int popularity;      // Spotify 0–100
  final int silenceOffset;
  final String hint1;        // e.g. "Pop song"
  final String hint2;        // e.g. "Released in the 2020s"
  final String hint3;        // e.g. "By Drake"
  final String spotifyId;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.audioUrl,
    required this.albumArtUrl,
    required this.genre,
    required this.language,
    required this.decade,
    required this.difficulty,
    required this.popularity,
    required this.silenceOffset,
    required this.hint1,
    required this.hint2,
    required this.hint3,
    required this.spotifyId,
  });

  factory Song.fromMap(Map<String, dynamic> map) => Song(
    id:            map['id']            as String? ?? '',
    title:         map['title']         as String? ?? '',
    artist:        map['artist']        as String? ?? '',
    album:         map['album']         as String? ?? '',
    audioUrl:      map['audioUrl']      as String? ?? '',
    albumArtUrl:   map['albumArtUrl']   as String? ?? '',
    genre:         map['genre']         as String? ?? '',
    language:      map['language']      as String? ?? '',
    decade:        map['decade']        as String? ?? '',
    difficulty:    map['difficulty']    as String? ?? 'medium',
    popularity:    (map['popularity']   as num?)?.toInt() ?? 0,
    silenceOffset: (map['silenceOffset'] as num?)?.toInt() ?? 0,
    hint1:         map['hint1']         as String? ?? '',
    hint2:         map['hint2']         as String? ?? '',
    hint3:         map['hint3']         as String? ?? '',
    spotifyId:     map['spotifyId']     as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id':            id,
    'title':         title,
    'artist':        artist,
    'album':         album,
    'audioUrl':      audioUrl,
    'albumArtUrl':   albumArtUrl,
    'genre':         genre,
    'language':      language,
    'decade':        decade,
    'difficulty':    difficulty,
    'popularity':    popularity,
    'silenceOffset': silenceOffset,
    'hint1':         hint1,
    'hint2':         hint2,
    'hint3':         hint3,
    'spotifyId':     spotifyId,
  };

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy':     return '🟢 Easy';
      case 'medium':   return '🟡 Medium';
      case 'hard':     return '🔴 Hard';
      case 'hardcore': return '💀 Hardcore';
      default:         return '⚪ Unknown';
    }
  }

  int get pointsMultiplier {
    switch (difficulty) {
      case 'easy':     return 1;
      case 'medium':   return 2;
      case 'hard':     return 3;
      case 'hardcore': return 5;
      default:         return 1;
    }
  }
}