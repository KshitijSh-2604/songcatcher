import 'dart:math';

enum GuessResult { correct, close, wrong }

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

  GuessResult checkGuess({
    required String guess,
    required String title,
  }) {
    final g = _normalize(guess);
    final t = _normalize(title);

    if (g.isEmpty || t.isEmpty) return GuessResult.wrong;

    // Exact match after normalization
    if (g == t) return GuessResult.correct;

    // Title contains guess or vice versa as a whole word
    if (t.split(' ').contains(g) || g.split(' ').contains(t)) {
       if (g.length > 3 && t.length > 3) return GuessResult.correct;
    }

    // Advanced Fuzzy Matching using Levenshtein distance
    final distance = _levenshtein(g, t);
    
    // Dynamic threshold based on actual title length
    int threshold;
    if (t.length > 10) {
      threshold = 3;
    } else if (t.length > 6) {
      threshold = 2;
    } else {
      threshold = 1;
    }

    if (distance <= threshold) return GuessResult.correct;
    
    // 🟠 "Close" logic: if it's within a few steps of the threshold
    if (distance <= threshold + 2) return GuessResult.close;

    return GuessResult.wrong;
  }

  bool isCorrectGuess({
    required String guess,
    required String title,
    required String artist,
  }) {
    return checkGuess(guess: guess, title: title) == GuessResult.correct;
  }

  /// Normalizes strings for matching: lowercases, removes special characters,
  /// and strips common song title suffixes like "(feat. ...)" or "- Remastered".
  String _normalize(String s) {
    String res = s.toLowerCase();
    
    // Remove common suffixes that users shouldn't be penalized for missing
    res = res.replaceAll(RegExp(r"[(\[].*?[)\]]"), ""); // Everything in () or []
    res = res.replaceAll(RegExp(r"\s-\s.*$"), "");       // Everything after " - "
    res = res.replaceAll(RegExp(r"feat\..*$", caseSensitive: false), "");
    
    // Remove all non-alphanumeric except spaces
    res = res.replaceAll(RegExp(r"[^a-z0-9\s]"), "");
    
    // Collapse multiple spaces and trim
    return res.replaceAll(RegExp(r"\s+"), " ").trim();
  }

  /// Efficient Levenshtein distance implementation using only two rows of space.
  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    // Ensure s2 is the shorter string to minimize space usage
    if (s1.length < s2.length) {
      final tmp = s1;
      s1 = s2;
      s2 = tmp;
    }

    final v0 = List<int>.generate(s2.length + 1, (i) => i);
    final v1 = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (var j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce(min);
      }

      for (var j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[s2.length];
  }
}