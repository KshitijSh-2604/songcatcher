import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/room.dart';
import 'scoring_service.dart';

class GameService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ── Room Management ────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    int totalRounds = 5,
  }) async {
    final code = _generateCode();
    final ref = _db.collection('rooms').doc();

    await ref.set({
      'code': code,
      'hostId': hostId,
      'status': 'waiting',
      'currentRound': 0,
      'totalRounds': totalRounds,
      'currentSongId': null,
      'roundStartTime': null,
      'revealedSeconds': 3,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ref.collection('players').doc(hostId).set({
      'displayName': hostName,
      'score': 0,
      'isReady': false,
      'hasGuessedCorrectly': false,
    });

    return ref.id;
  }

  Future<String?> joinRoom({
    required String code,
    required String userId,
    required String displayName,
  }) async {
    final snap = await _db
        .collection('rooms')
        .where('code', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final roomId = snap.docs.first.id;
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .doc(userId)
        .set({
      'displayName': displayName,
      'score': 0,
      'isReady': false,
      'hasGuessedCorrectly': false,
    });

    return roomId;
  }

  // ── Round Management ───────────────────────────────────────────────────────

  Future<void> startGame(String roomId) async {
    await _nextRound(roomId, roundNumber: 1);
    await _db.collection('rooms').doc(roomId).update({'status': 'playing'});
  }

  Future<void> _nextRound(String roomId, {required int roundNumber}) async {
    final song = await _pickRandomSong();
    await _db.collection('rooms').doc(roomId).update({
      'currentRound': roundNumber,
      'currentSongId': song.id,
      'roundStartTime': FieldValue.serverTimestamp(),
      'revealedSeconds': 3, // always start at 3s
    });

    // Reset all players' hasGuessedCorrectly
    final players = await _db
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .get();
    final batch = _db.batch();
    for (final p in players.docs) {
      batch.update(p.reference, {'hasGuessedCorrectly': false});
    }
    await batch.commit();
  }

  // ── Clip Reveal (host triggers) ────────────────────────────────────────────

  Future<void> revealMoreClip(String roomId, int seconds) async {
    await _db.collection('rooms').doc(roomId).update({
      'revealedSeconds': seconds,
    });
  }

  // ── Guessing ───────────────────────────────────────────────────────────────

  Future<bool> submitGuess({
    required String roomId,
    required String userId,
    required String guessText,
    required String correctTitle,
    required String correctArtist,
    required int revealedSeconds,
  }) async {
    final isCorrect = _isCorrectGuess(guessText, correctTitle, correctArtist);

    // Save guess
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('guesses')
        .doc(userId)
        .collection('attempts')
        .doc(_uuid.v4())
        .set({
      'text': guessText,
      'isCorrect': isCorrect,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (isCorrect) {
      // Count how many already guessed correctly
      final playersSnap = await _db
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .where('hasGuessedCorrectly', isEqualTo: true)
          .get();

      final points = ScoringService.calculatePoints(
        correctGuessersCount: playersSnap.docs.length,
        revealedSeconds: revealedSeconds,
      );

      // Update player score
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .doc(userId)
          .update({
        'hasGuessedCorrectly': true,
        'score': FieldValue.increment(points),
      });
    }

    return isCorrect;
  }

  bool _isCorrectGuess(String guess, String title, String artist) {
    final g = _normalize(guess);
    final t = _normalize(title);
    final a = _normalize(artist);
    // Accept: exact title match, or "artist - title", or title contains guess
    return g == t ||
        g == '$a $t' ||
        g.contains(t) ||
        t.contains(g) ||
        _levenshteinSimilar(g, t);
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\s]"), '').trim();

  bool _levenshteinSimilar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    // Allow 1 typo per 5 characters
    final maxDist = (b.length / 5).floor().clamp(1, 3);
    return _levenshtein(a, b) <= maxDist;
  }

  int _levenshtein(String a, String b) {
    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i-1][j], dp[i][j-1], dp[i-1][j-1]].reduce((a,b) => a < b ? a : b);
      }
    }
    return dp[m][n];
  }

  // Add inside GameService class in game_service.dart
  Future<void> updateRounds(String roomId, int rounds) async {
    await _db.collection('rooms').doc(roomId).update({'totalRounds': rounds});
  }

  Future<void> endRound(String roomId, Room room) async {
    if (room.currentRound >= room.totalRounds) {
      await _db.collection('rooms').doc(roomId).update({'status': 'finished'});
    } else {
      await _nextRound(roomId, roundNumber: room.currentRound + 1);
    }
  }

  // ── Songs ──────────────────────────────────────────────────────────────────

  Future<({String id, Map<String, dynamic> data})> _pickRandomSong() async {
    final snap = await _db.collection('songs').get();
    final docs = snap.docs..shuffle();
    final doc = docs.first;
    return (id: doc.id, data: doc.data());
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = List.generate(6, (_) {
      return chars[DateTime.now().microsecondsSinceEpoch % chars.length];
    });
    return rand.join();
  }
}