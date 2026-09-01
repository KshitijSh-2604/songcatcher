import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/daily_challenge.dart';
import '../models/song.dart';
import 'itunes_service.dart';
import 'scoring_service.dart';

class DailyChallengeService {
  final _db = FirebaseFirestore.instance;
  final _itunes = ItunesService();
  final _scoring = ScoringService();

  String get _todayStr => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<DailyChallenge> getOrCreateChallenge(String vibe) async {
    // Ensure we only use core vibes for daily challenge
    final coreVibes = ['Bollywood', 'Punjabi', 'English', 'International'];
    final normalizedVibe = coreVibes.contains(vibe) ? vibe : 'English';

    final id = '${_todayStr}_$normalizedVibe';

    // Check if it's payout time (11:55 PM to 12:00 AM) or if we need to catch up
    final now = DateTime.now();
    if (now.hour == 23 && now.minute >= 55) {
       await _calculateAndAwardMusCoins(normalizedVibe);
    }

    final doc = await _db.collection('daily_challenges').doc(id).get();

    if (doc.exists && doc.data() != null) {
      return DailyChallenge.fromMap(doc.id, doc.data() as Map<String, dynamic>);
    }

    // Create new challenge for the core vibe
    final songs = await _itunes.fetchSongsForRoom(
      genre: normalizedVibe,
      yearFrom: 1980, // 🎵 Focus on more modern hits for daily challenge variety
      yearTo: DateTime.now().year,
      count: 10, // Fetch more to shuffle
    );

    final challenge = DailyChallenge(
      id: id,
      date: _todayStr,
      vibe: vibe,
      songs: (songs..shuffle()).take(5).toList(),
      createdAt: DateTime.now(),
    );

    await _db.collection('daily_challenges').doc(id).set(challenge.toMap());
    return challenge;
  }

  Future<DailyAttempt?> getAttempt(String userId, String vibe) async {
    final id = '${_todayStr}_${vibe}_$userId';
    final doc = await _db.collection('daily_attempts').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return DailyAttempt.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Future<void> startAttempt(String userId, String displayName, String? photoUrl, Map<String, dynamic> avatarConfig, String vibe) async {
    final id = '${_todayStr}_${vibe}_$userId';
    final attempt = DailyAttempt(
      id: id,
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
      avatarConfig: avatarConfig,
      date: _todayStr,
      vibe: vibe,
      updatedAt: DateTime.now(),
    );
    await _db.collection('daily_attempts').doc(id).set(attempt.toMap());
  }

  Future<void> completeAttempt(String userId, String vibe, int score, int correctCount, int timeMs, int tries) async {
    final id = '${_todayStr}_${vibe}_$userId';
    await _db.collection('daily_attempts').doc(id).update({
      'score': score,
      'correctCount': correctCount,
      'totalTimeMs': timeMs,
      'totalTries': tries,
      'completed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Award daily stats immediately
    await _db.collection('users').doc(userId).set({
      'dailyStats': {
        'totalPoints': FieldValue.increment(score),
        'challengesPlayed': FieldValue.increment(1),
        if (correctCount == 5) 'perfectScores': FieldValue.increment(1),
      }
    }, SetOptions(merge: true));

    // Check if it's payout time (11:55 PM to 12:00 AM)
    final now = DateTime.now();
    if (now.hour == 23 && now.minute >= 55) {
      await _calculateAndAwardMusCoins(vibe);
    }
  }

  Future<void> _calculateAndAwardMusCoins(String vibe, {String? dateStr}) async {
    final dayId = dateStr ?? _todayStr;
    
    // NEW RANKING: Max correct -> lowest tries -> lowest time -> earliest solved
    final leaderboardSnap = await _db
        .collection('daily_attempts')
        .where('date', isEqualTo: dayId)
        .where('vibe', isEqualTo: vibe)
        .where('completed', isEqualTo: true)
        .orderBy('correctCount', descending: true)
        .limit(20)
        .get();

    final rewards = [1000, 800, 600, 500, 400, 200, 200, 200, 200, 200, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100];

    final batch = _db.batch();
    bool updated = false;
    for (int i = 0; i < leaderboardSnap.docs.length; i++) {
      final doc = leaderboardSnap.docs[i];
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      final reward = rewards[i];
      
      if (userId != null && data['rewarded'] != true) {
        batch.update(doc.reference, {'rewarded': true});
        batch.update(_db.collection('users').doc(userId), {
          'musCoins': FieldValue.increment(reward),
        });
        updated = true;
      }
    }
    if (updated) await batch.commit();
  }

  Stream<List<DailyAttempt>> watchLeaderboard(String vibe) {
    // Attempt full ranking, will fall back if index missing
    return _db
        .collection('daily_attempts')
        .where('date', isEqualTo: _todayStr)
        .where('vibe', isEqualTo: vibe)
        .where('completed', isEqualTo: true)
        .orderBy('correctCount', descending: true)
        .orderBy('totalTries', descending: false)
        .orderBy('totalTimeMs', descending: false)
        .orderBy('updatedAt', descending: false)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DailyAttempt.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  /// ONE-TIME CLEAR: Call this to reset all challenges and attempts for today (dev only)
  Future<void> clearTodayAttempts() async {
    final attemptsSnap = await _db
        .collection('daily_attempts')
        .where('date', isEqualTo: _todayStr)
        .get();
    
    final challengesSnap = await _db
        .collection('daily_challenges')
        .where('date', isEqualTo: _todayStr)
        .get();

    final batch = _db.batch();
    for (var doc in attemptsSnap.docs) {
      batch.delete(doc.reference);
    }
    for (var doc in challengesSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
