import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/player.dart';
import 'scoring_service.dart';

class GameService {
  final _db = FirebaseFirestore.instance;
  final _scoring = ScoringService();
  final _rand = Random();

  // ── Create room ──────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    int totalRounds = 10,
    String? language,
    String? genre,
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
      'revealedSeconds': 3,
      'roundStartedAt': null,
      'language': language,
      'genre': genre,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add host as first player
    await ref.collection('players').doc(hostId).set({
      'displayName': hostName,
      'score': 0,
      'correctGuesses': 0,
      'hasGuessedCorrectly': false,
      'isOnline': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // ── Join room ────────────────────────────────────────────────────────────

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
      'correctGuesses': 0,
      'hasGuessedCorrectly': false,
      'isOnline': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return roomId;
  }

  // ── Start game (host only) ───────────────────────────────────────────────

  Future<void> startGame(String roomId) async {
    final songId = await _pickRandomSong(roomId);
    if (songId == null) throw Exception('No songs found. Please seed the song library first.');

    await _db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'currentRound': 1,
      'currentSongId': songId,
      'revealedSeconds': 3,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Submit guess ─────────────────────────────────────────────────────────

  Future<bool> submitGuess({
    required String roomId,
    required String userId,
    required String guess,
  }) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final room = Room.fromMap(roomDoc.id, roomDoc.data()!);
    if (room.currentSongId == null) return false;

    final songDoc = await _db.collection('songs').doc(room.currentSongId).get();
    final songData = songDoc.data()!;
    final title = songData['title'] as String;
    final artist = songData['artist'] as String;

    final correct = _scoring.isCorrectGuess(
      guess: guess,
      title: title,
      artist: artist,
    );

    // Write the guess to Firestore
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('guesses')
        .add({
      'userId': userId,
      'guess': guess,
      'correct': correct,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (correct) {
      // Check if first correct guesser
      final correctSnap = await _db
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .where('hasGuessedCorrectly', isEqualTo: true)
          .limit(1)
          .get();

      final isFirst = correctSnap.docs.isEmpty;
      final now = DateTime.now();
      final roundStart = room.roundStartedAt?.toDate() ?? now;
      final elapsedMs = now.difference(roundStart).inMilliseconds.abs();

      final points = _scoring.calculatePoints(
        revealedSeconds: room.revealedSeconds,
        elapsedMs: elapsedMs,
        isFirstCorrect: isFirst,
      );

      // Award score
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .doc(userId)
          .update({
        'score': FieldValue.increment(points),
        'correctGuesses': FieldValue.increment(1),
        'hasGuessedCorrectly': true,
      });
    }

    return correct;
  }

  // ── Reveal more of the clip (host only) ──────────────────────────────────

  Future<void> revealMoreClip(String roomId, int seconds) async {
    await _db.collection('rooms').doc(roomId).update({
      'revealedSeconds': seconds,
    });
  }

  // ── End round + advance (host only) ─────────────────────────────────────

  Future<void> endRound(String roomId, Room room) async {
    if (room.currentRound >= room.totalRounds) {
      // Game over
      await _db.collection('rooms').doc(roomId).update({
        'status': 'finished',
      });
      return;
    }

    // Pick next song
    final nextSongId = await _pickRandomSong(roomId);

    // Reset all players' hasGuessedCorrectly
    final playersSnap = await _db
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .get();

    final batch = _db.batch();
    for (final doc in playersSnap.docs) {
      batch.update(doc.reference, {'hasGuessedCorrectly': false});
    }
    await batch.commit();

    // Advance round
    await _db.collection('rooms').doc(roomId).update({
      'currentRound': room.currentRound + 1,
      'currentSongId': nextSongId,
      'revealedSeconds': 3,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Pick a random song from Firestore ────────────────────────────────────

  Future<String?> _pickRandomSong(String roomId) async {
    // Get room to check language/genre filters
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final data = roomDoc.data()!;
    final language = data['language'] as String?;
    final genre = data['genre'] as String?;

    Query query = _db.collection('songs');
    if (language != null) query = query.where('language', isEqualTo: language);
    if (genre != null) query = query.where('genre', isEqualTo: genre);

    // Get already-played song IDs this game to avoid repeats
    // (use a simple random approach — get up to 200 songs, pick one)
    final snap = await query.limit(200).get();
    if (snap.docs.isEmpty) return null;

    final randomIndex = _rand.nextInt(snap.docs.length);
    return snap.docs[randomIndex].id;
  }

  // ── Generate 6-char room code ────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
}