import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/player.dart';
import '../models/song.dart';          // ← ADDED
import 'scoring_service.dart';
import 'itunes_service.dart';         // ← ADDED

class GameService {
  final _db      = FirebaseFirestore.instance;
  final _scoring = ScoringService();
  final _rand    = Random();

  // ← ADDED: in-memory song queue per room (host device only)
  // Maps roomId → list of pre-fetched songs for this game session
  final Map<String, List<Song>> _songQueue = {};
  final _spotify = ItunesService();

  // ── Create room ──────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    int totalRounds = 10,
    String? language,
    String? genre,
    String difficulty = 'medium',       // ← ADDED
  }) async {
    final code = _generateCode();
    final ref  = _db.collection('rooms').doc();

    await ref.set({
      'code':           code,
      'hostId':         hostId,
      'status':         'waiting',
      'currentRound':   0,
      'totalRounds':    totalRounds,
      'currentSong':    null,           // ← CHANGED: was currentSongId (String), now a Map
      'revealedSeconds': 3,
      'roundStartedAt': null,
      'language':       language,
      'genre':          genre,
      'difficulty':     difficulty,     // ← ADDED
      'createdAt':      FieldValue.serverTimestamp(),
    });

    await ref.collection('players').doc(hostId).set({
      'displayName':        hostName,
      'score':              0,
      'correctGuesses':     0,
      'hasGuessedCorrectly': false,
      'isOnline':           true,
      'joinedAt':           FieldValue.serverTimestamp(),
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
        .where('code',   isEqualTo: code.toUpperCase())
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
      'displayName':         displayName,
      'score':               0,
      'correctGuesses':      0,
      'hasGuessedCorrectly': false,
      'isOnline':            true,
      'joinedAt':            FieldValue.serverTimestamp(),
    });

    return roomId;
  }

  // ── Start game (host only) ───────────────────────────────────────────────
  // ← CHANGED: pre-fetches all songs from Spotify upfront, no Firestore songs collection

  Future<void> startGame(String roomId) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final data    = roomDoc.data()!;

    final genre      = (data['genre'] as String?)?.isNotEmpty == true
        ? data['genre'] as String
        : 'Mix';                                        // ← never null
    final language   = data['language']   as String?;
    final difficulty = (data['difficulty'] as String?)?.isNotEmpty == true
        ? data['difficulty'] as String
        : 'medium';
    final totalRounds = (data['totalRounds'] as num?)?.toInt() ?? 10;

    // Fetch songs from Spotify (fetch extra as buffer)
    final songs = await _fetchSongsFromSpotify(
      genre:      genre,
      language:   language,
      difficulty: difficulty,
      count:      totalRounds + 5,
    );

    // In startGame, replace the throw:
    if (songs.isEmpty) {
      throw Exception(
        'Could not find songs with audio previews on Spotify.\n'
            'Spotify has removed previews from most tracks.\n'
            'Please try again — a different set of tracks may have previews.',
      );
    }

    // Cache the queue on the host device
    _songQueue[roomId] = List.from(songs)..shuffle(_rand);

    final first = _songQueue[roomId]!.first;

    await _db.collection('rooms').doc(roomId).update({
      'status':        'playing',
      'currentRound':  1,
      'currentSong':   first.toMap(),   // ← CHANGED: full song map, not just ID
      'revealedSeconds': 3,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Submit guess ─────────────────────────────────────────────────────────
  // ← CHANGED: reads song title/artist from room.currentSong map, not Firestore songs collection

  Future<bool> submitGuess({
    required String roomId,
    required String userId,
    required String guess,
  }) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final room    = Room.fromMap(roomDoc.id, roomDoc.data()!);

    // ← CHANGED: song data comes from the room document, not a separate songs collection
    final songData = room.currentSong;
    if (songData == null) return false;

    final title  = songData['title']  as String? ?? '';
    final artist = songData['artist'] as String? ?? '';

    final correct = _scoring.isCorrectGuess(
      guess:  guess,
      title:  title,
      artist: artist,
    );

    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('guesses')
        .add({
      'userId':    userId,
      'guess':     guess,
      'correct':   correct,
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

      final isFirst   = correctSnap.docs.isEmpty;
      final now       = DateTime.now();
      final roundStart = room.roundStartedAt?.toDate() ?? now;
      final elapsedMs  = now.difference(roundStart).inMilliseconds.abs();

      final points = _scoring.calculatePoints(
        revealedSeconds: room.revealedSeconds,
        elapsedMs:       elapsedMs,
        isFirstCorrect:  isFirst,
      );

      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .doc(userId)
          .update({
        'score':               FieldValue.increment(points),
        'correctGuesses':      FieldValue.increment(1),
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
  // ← CHANGED: picks next song from in-memory queue, not Firestore

  Future<void> endRound(String roomId, Room room) async {
    if (room.currentRound >= room.totalRounds) {
      await _db.collection('rooms').doc(roomId).update({'status': 'finished'});
      return;
    }

    // ← CHANGED: pop next song from the cached queue
    final queue = _songQueue[roomId];
    Song? nextSong;

    if (queue != null && queue.length > 1) {
      queue.removeAt(0);           // discard just-played song
      nextSong = queue.first;
    } else {
      // Queue exhausted or host app restarted — re-fetch
      final roomDoc  = await _db.collection('rooms').doc(roomId).get();
      final data     = roomDoc.data()!;
      final newSongs = await _fetchSongsFromSpotify(
        genre:      data['genre']      as String?,
        language:   data['language']   as String?,
        difficulty: data['difficulty'] as String? ?? 'medium',
        count:      room.totalRounds,
      );
      if (newSongs.isNotEmpty) {
        _songQueue[roomId] = List.from(newSongs)..shuffle(_rand);
        nextSong = _songQueue[roomId]!.first;
      }
    }

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

    await _db.collection('rooms').doc(roomId).update({
      'currentRound':   room.currentRound + 1,
      'currentSong':    nextSong?.toMap(),    // ← CHANGED: full map, not ID
      'revealedSeconds': 3,
      'roundStartedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Fetch songs from Spotify ─────────────────────────────────────────────
  // ← ADDED: replaces _pickRandomSong which queried Firestore songs collection

  Future<List<Song>> _fetchSongsFromSpotify({
    String? genre,
    String? language,
    String? difficulty,
    int count = 15,
  }) async {
    if (genre == null || genre == 'Mix') {
      return _spotify.fetchMixedSongs(count: count);
    }
    return _spotify.fetchSongsForRoom(
      difficulty: difficulty ?? 'medium',
      genre:      genre,
      language:   language,
      count:      count,
    );
  }

  // ── Generate 6-char room code ────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
}