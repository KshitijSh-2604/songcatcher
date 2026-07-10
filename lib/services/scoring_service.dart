import 'dart:math';

class ScoringService {
  // Max points awarded per reveal stage — earlier/shorter clip guessed
  // correctly is worth more. Difficulty multiplier scales on top of this.
  static const Map<int, int> _stageCeilings = {
    2: 1000,
    3: 800,
    5: 500,
    10: 250,
  };

  static const Map<String, double> _difficultyMultiplier = {
    'easy': 1.0,
    'medium': 1.25,
    'hard': 1.5,
  };

  static const _firstBonus = 100;
  static const _minScore = 25;

  // ── Score calculation ────────────────────────────────────────────────────
  //
  // Points are capped by which reveal stage the clip was on when guessed
  // (earlier stage = higher ceiling), then scaled up by song difficulty
  // (harder songs = more points, since they're rarer/less well-known),
  // then a small speed bonus within that stage, plus a first-to-guess bonus.

  int calculatePoints({
    required int revealedSeconds,
    required int elapsedMs,
    required bool isFirstCorrect,
    required String songDifficulty,
  }) {
    final ceiling = _stageCeilings[revealedSeconds] ?? _stageCeilings.values.last;
    final multiplier = _difficultyMultiplier[songDifficulty] ?? 1.0;

    // Small in-stage speed bonus: guessing right at the start of a stage
    // scores closer to the ceiling than guessing right before it ends.
    final speedRatio = (1 - (elapsedMs / 15000)).clamp(0.0, 1.0);
    final speedAdjusted = ceiling * (0.7 + 0.3 * speedRatio);

    int points = (speedAdjusted * multiplier).round();
    if (isFirstCorrect) points += _firstBonus;

    return points.clamp(_minScore, 1000);
  }

  // ── Fuzzy guess matching ─────────────────────────────────────────────────

  bool isCorrectGuess({
    required String guess,
    required String title,
    required String artist,
  }) {
    final g = _normalize(guess);
    final t = _normalize(title);
    final a = _normalize(artist);

    if (g.isEmpty) return false;

    // Exact match on title or artist
    if (g == t || g == a) return true;

    // Title contains guess or vice versa
    if (t.contains(g) || g.contains(t)) return true;

    // Fuzzy: Levenshtein distance on title
    if (g.length >= 4 && _levenshtein(g, t) <= 2) return true;

    // Fuzzy: Levenshtein on first artist name
    final firstArtist = a.split(',').first.trim();
    if (g.length >= 4 && _levenshtein(g, firstArtist) <= 2) return true;

    return false;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s]"), '').trim();

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final d = List.generate(
        a.length + 1, (i) => List.generate(b.length + 1, (j) => j == 0 ? i : 0));
    for (var j = 1; j <= b.length; j++) d[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        d[i][j] = a[i - 1] == b[j - 1]
            ? d[i - 1][j - 1]
            : 1 + [d[i - 1][j], d[i][j - 1], d[i - 1][j - 1]].reduce(min);
      }
    }
    return d[a.length][b.length];
  }
}