class Player {
  final String id;
  final String displayName;
  final String? photoUrl;
  final Map<String, dynamic> avatarConfig;
  final int score;
  final int correctGuesses;
  final bool hasGuessedCorrectly;
  final bool isOnline;
  final int lastPointsEarned;
  final bool isTyping; // 🆕 New field
  final bool isReady;  // 🆕 Added
  final int totalElapsedMs; // 🆕 Added
  final int hardCorrectGuesses; // 🆕 Added

  const Player({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.avatarConfig = const {},
    required this.score,
    required this.correctGuesses,
    required this.hasGuessedCorrectly,
    required this.isOnline,
    this.lastPointsEarned = 0,
    this.isTyping = false,
    this.isReady = false,
    this.totalElapsedMs = 0,
    this.hardCorrectGuesses = 0,
  });

  factory Player.fromMap(String id, Map<String, dynamic> d) {
    return Player(
      id: id,
      displayName: d['displayName'] ?? 'Player',
      photoUrl: d['photoUrl'],
      avatarConfig: Map<String, dynamic>.from(d['avatarConfig'] ?? {}),
      score: d['score'] ?? 0,
      correctGuesses: d['correctGuesses'] ?? 0,
      hasGuessedCorrectly: d['hasGuessedCorrectly'] ?? false,
      isOnline: d['isOnline'] ?? true,
      lastPointsEarned: d['lastPointsEarned'] ?? 0,
      isTyping: d['isTyping'] ?? false,
      isReady: d['isReady'] ?? false,
      totalElapsedMs: (d['totalElapsedMs'] as num?)?.toInt() ?? 0,
      hardCorrectGuesses: (d['hardCorrectGuesses'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'photoUrl': photoUrl,
    'avatarConfig': avatarConfig,
    'score': score,
    'correctGuesses': correctGuesses,
    'hasGuessedCorrectly': hasGuessedCorrectly,
    'isOnline': isOnline,
    'lastPointsEarned': lastPointsEarned,
    'isTyping': isTyping,
    'isReady': isReady,
    'totalElapsedMs': totalElapsedMs,
    'hardCorrectGuesses': hardCorrectGuesses,
  };
}