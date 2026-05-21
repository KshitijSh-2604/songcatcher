class Player {
  final String id;
  final String displayName;
  final int score;
  final int correctGuesses;
  final bool hasGuessedCorrectly;
  final bool isOnline;

  const Player({
    required this.id,
    required this.displayName,
    required this.score,
    required this.correctGuesses,
    required this.hasGuessedCorrectly,
    required this.isOnline,
  });

  factory Player.fromMap(String id, Map<String, dynamic> d) {
    return Player(
      id: id,
      displayName: d['displayName'] ?? 'Player',
      score: d['score'] ?? 0,
      correctGuesses: d['correctGuesses'] ?? 0,
      hasGuessedCorrectly: d['hasGuessedCorrectly'] ?? false,
      isOnline: d['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'score': score,
    'correctGuesses': correctGuesses,
    'hasGuessedCorrectly': hasGuessedCorrectly,
    'isOnline': isOnline,
  };
}