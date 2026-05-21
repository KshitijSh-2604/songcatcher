import 'dart:math';

class ScoringService {
  static const _baseScore      = 1000;
  static const _firstBonus     = 500;
  static const _speedMaxBonus  = 300;
  static const _minScore       = 50;

  // ── Score calculation (was in Cloud Function) ────────────────────────────

  int calculatePoints({
    required int revealedSeconds,
    required int elapsedMs,
    required bool isFirstCorrect,
  }) {
    final penalty = _clipPenalty(revealedSeconds);
    final speed   = _speedBonus(elapsedMs);

    int points = _baseScore - penalty + speed;
    if (isFirstCorrect) points += _firstBonus;
    return points.clamp(_minScore, 2000);
  }

  int _clipPenalty(int seconds) {
    if (seconds <= 3) return 0;
    if (seconds <= 5) return 200;
    return 400;
  }

  int _speedBonus(int elapsedMs) {
    final ratio = (1 - (elapsedMs - 3000) / 12000).clamp(0.0, 1.0);
    return (ratio * _speedMaxBonus).round();
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