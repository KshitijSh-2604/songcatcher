class ScoringService {
  static const int basePoints = 1000;
  static const int minPoints = 200;
  static const int perGuesserPenalty = 100;
  static const int speedBonus = 200;

  /// [correctGuessersCount] = how many players already guessed correctly
  /// [revealedSeconds] = which clip length was playing (3, 5, 10)
  static int calculatePoints({
    required int correctGuessersCount,
    required int revealedSeconds,
  }) {
    // Base deduction per person who already got it
    int points = basePoints - (correctGuessersCount * perGuesserPenalty);
    points = points.clamp(minPoints, basePoints);

    // Multiplier by clip length
    double multiplier = switch (revealedSeconds) {
      3 => 1.0,
      5 => 0.7,
      10 => 0.4,
      _ => 0.4,
    };

    points = (points * multiplier).round();

    // Speed bonus for 3s clip
    if (revealedSeconds == 3) points += speedBonus;

    return points;
  }
}