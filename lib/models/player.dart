class Player {
  final String id;
  final String displayName;
  final int score;
  final bool isReady;
  final bool hasGuessedCorrectly;

  const Player({
    required this.id,
    required this.displayName,
    required this.score,
    required this.isReady,
    required this.hasGuessedCorrectly,
  });

  factory Player.fromMap(String id, Map<String, dynamic> data) {
    return Player(
      id: id,
      displayName: data['displayName'] ?? 'Player',
      score: data['score'] ?? 0,
      isReady: data['isReady'] ?? false,
      hasGuessedCorrectly: data['hasGuessedCorrectly'] ?? false,
    );
  }
}