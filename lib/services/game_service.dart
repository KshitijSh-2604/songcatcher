import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../models/song.dart';
import 'scoring_service.dart';
import 'itunes_service.dart';

class GameService {
  final _db = FirebaseFirestore.instance;
  final _scoring = ScoringService();
  final _rand = Random();

  final Map<String, List<Song>> _songQueue = {};
  final _spotify = ItunesService();

  // Clip reveal stages, in seconds — 2s option added per request.
  static const revealStages = [2, 3, 5, 10];

  // ── Create room ──────────────────────────────────────────────────────────
  //
  // Difficulty is intentionally NOT a parameter here — it's auto-randomized
  // and weighted per-round inside ItunesService, never host-selected.

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    int totalRounds = 10,
    String genre = 'Bollywood',
    int yearFrom = 1950,
    int yearTo = 2020,
  }) async {
    final code = _generateCode();
    final ref = _db.collection('rooms').doc();

    await ref.set({
      'code': code,
      'hostId': hostId,
      'status': 'waiting',
      'currentRound': 0,
      'totalRounds': totalRounds.clamp(1, 25),
      'currentSong': null,
      'revealedSeconds': revealStages.first,
      'roundStartedAt': null,
      'genre': genre,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
      'createdAt': FieldValue.serverTimestamp(),
    });

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

  // ── Update room settings (host only, lobby pre-game) ─────────────────────

  Future<void> updateRoomSettings(
      String roomId, {
        required int yearRangeStart,
        required int yearRangeEnd,
        required int totalRounds,
      }) async {
    await _db.collection('rooms').doc(roomId).update({
      'yearFrom': yearRangeStart,
      'yearTo': yearRangeEnd,
      'totalRounds': totalRounds.clamp(1, 25),
    });
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

    await _db.collection('rooms').doc(roomId).collection('players').doc(userId).set({
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
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final data = roomDoc.data()!;

    final genre = 'Bollywood';
    final totalRounds = (data['totalRounds'] as num?)?.toInt() ?? 10;
    final yearFrom = (data['yearFrom'] as num?)?.toInt() ?? 1950;
    final yearTo = (data['yearTo'] as num?)?.toInt() ?? 2020;

    final songs = await _fetchSongsFromSpotify(
      genre: genre,
      yearFrom: yearFrom,
      yearTo: yearTo,
      count: totalRounds + 5,
    );

    if (songs.isEmpty) {
      throw Exception(
        'Could not find Bollywood songs with audio previews for that year range.\n'
            'Try widening the year range and starting again.',
      );
    }

    _songQueue[roomId] = List.from(songs)..shuffle(_rand);

    final first = _songQueue[roomId]!.first;

    await _db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'currentRound': 1,
      'currentSong': first.toMap(),
      'revealedSeconds': revealStages.first,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Submit guess ─────────────────────────────────────────────────────────

  Future<bool> submitGuess({
    required String roomId,
    required String userId,
    required String displayName,
    required String guess,
  }) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final room = Room.fromMap(roomDoc.id, roomDoc.data()!);

    final songData = room.currentSong;
    if (songData == null) return false;

    // Player already caught it this round, or round already over — no-op.
    final playerDoc = await _db.collection('rooms').doc(roomId).collection('players').doc(userId).get();
    if (playerDoc.data()?['hasGuessedCorrectly'] == true) return false;

    final title = songData['title'] as String? ?? '';
    final artist = songData['artist'] as String? ?? '';

    final correct = _scoring.isCorrectGuess(guess: guess, title: title, artist: artist);

    // Store the guess. If correct, we don't store the raw guess text in a way
    // that other players can read it — the guess_history / chat UI must show
    // "<name> caught it!" instead of the actual answer for correct guesses.
    await _db.collection('rooms').doc(roomId).collection('guesses').add({
      'userId': userId,
      'displayName': displayName,
      'guess': correct ? '' : guess,
      'correct': correct,
      'roundNumber': room.currentRound,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (correct) {
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
        songDifficulty: songData['difficulty'] as String? ?? 'medium',
      );

      await _db.collection('rooms').doc(roomId).collection('players').doc(userId).update({
        'score': FieldValue.increment(points),
        'correctGuesses': FieldValue.increment(1),
        'hasGuessedCorrectly': true,
      });
    }

    return correct;
  }

  // ── Reveal more of the clip (host only) ──────────────────────────────────

  Future<void> revealMoreClip(String roomId, int seconds) async {
    await _db.collection('rooms').doc(roomId).update({'revealedSeconds': seconds});
  }

  // ── Force-end the round if it's still active ─────────────────────────────
  // Called by the timer when time runs out with nobody guessing. Guards
  // against double-firing across clients by checking status first.

  Future<void> forceEndRoundIfActive(String roomId) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final data = roomDoc.data();
    if (data == null) return;
    if (data['status'] != 'playing') return;

    await _db.collection('rooms').doc(roomId).update({'status': 'roundEnded'});
  }

  // ── End round + advance (host only) ─────────────────────────────────────

  Future<void> endRound(String roomId, Room room) async {
    if (room.currentRound >= room.totalRounds) {
      await _db.collection('rooms').doc(roomId).update({'status': 'finished'});
      return;
    }

    final queue = _songQueue[roomId];
    Song? nextSong;

    if (queue != null && queue.length > 1) {
      queue.removeAt(0);
      nextSong = queue.first;
    } else {
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      final data = roomDoc.data()!;
      final newSongs = await _fetchSongsFromSpotify(
        genre: data['genre'] as String? ?? 'Bollywood',
        yearFrom: (data['yearFrom'] as num?)?.toInt() ?? 1950,
        yearTo: (data['yearTo'] as num?)?.toInt() ?? 2020,
        count: room.totalRounds,
      );
      if (newSongs.isNotEmpty) {
        _songQueue[roomId] = List.from(newSongs)..shuffle(_rand);
        nextSong = _songQueue[roomId]!.first;
      }
    }

    final playersSnap = await _db.collection('rooms').doc(roomId).collection('players').get();

    final batch = _db.batch();
    for (final doc in playersSnap.docs) {
      batch.update(doc.reference, {'hasGuessedCorrectly': false});
    }
    await batch.commit();

    await _db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'currentRound': room.currentRound + 1,
      'currentSong': nextSong?.toMap(),
      'revealedSeconds': revealStages.first,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Fetch songs from iTunes — Bollywood only, year-ranged, difficulty
  //    auto-mixed internally by ItunesService ────────────────────────────

  Future<List<Song>> _fetchSongsFromSpotify({
    required String genre,
    required int yearFrom,
    required int yearTo,
    int count = 15,
  }) {
    return _spotify.fetchSongsForRoom(
      genre: genre,
      yearFrom: yearFrom,
      yearTo: yearTo,
      count: count,
    );
  }

  // ── Generate 6-char room code ────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
}