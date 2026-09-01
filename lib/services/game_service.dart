import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../models/song.dart';
import 'scoring_service.dart';
import 'itunes_service.dart';

class GameService {
  final _db = FirebaseFirestore.instance;
  final _scoring = ScoringService();
  final _rand = Random();

  final Map<String, List<Song>> _songQueue = {};
  final _itunes = ItunesService();

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    String? photoUrl,
    Map<String, dynamic> avatarConfig = const {},
    int totalRounds = 10,
    List<String> selectedVibes = const ['Bollywood'],
    List<int> selectedClipStages = const [2, 3, 5],
    int yearFrom = 1950,
    int yearTo = 2030,
    bool isPublic = false,
    bool isPartyMode = false,
    bool forceLockVisibility = false, // 🔒 New field
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
      'revealedSeconds': selectedClipStages.first,
      'roundStartedAt': null,
      'selectedVibes': selectedVibes,
      'selectedClipStages': selectedClipStages,
      'yearFrom': yearFrom,
      'yearTo': yearTo,
      'isPublic': isPublic,
      'isPartyMode': isPartyMode,
      'forceLockVisibility': forceLockVisibility,
      'createdAt': FieldValue.serverTimestamp(),
      'skipVotes': [],
    });

    final cleanName = _filterName(hostName);
    await ref.collection('players').doc(hostId).set({
      'displayName': cleanName,
      'photoUrl': photoUrl,
      'avatarConfig': avatarConfig,
      'score': 0,
      'correctGuesses': 0,
      'hasGuessedCorrectly': false,
      'isOnline': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<String?> findPublicRoom({
    required String userId,
    required String displayName,
    String? photoUrl,
    Map<String, dynamic> avatarConfig = const {},
  }) async {
    // 1. Try to find rooms that are still WAITING (best experience)
    final waitingSnap = await _db
        .collection('rooms')
        .where('isPublic', isEqualTo: true)
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    // 2. Try to find rooms that already started but aren't finished
    final activeSnap = await _db
        .collection('rooms')
        .where('isPublic', isEqualTo: true)
        .where('status', whereIn: ['playing', 'roundEnded'])
        .limit(10)
        .get();

    final allDocs = [...waitingSnap.docs, ...activeSnap.docs];

    for (final doc in allDocs) {
      final data = doc.data();
      
      // If I'm already in this room (e.g. refreshed page), return it immediately
      final playerDoc = await doc.reference.collection('players').doc(userId).get();
      if (playerDoc.exists) return doc.id;

      // Skip rooms I just left (where I am still recorded as hostId but removed from players)
      if (data['hostId'] == userId) continue;

      // Check if room has space (max 8)
      final playersSnap = await doc.reference.collection('players').get();
      if (playersSnap.docs.isEmpty) {
        await doc.reference.delete(); // Cleanup zombie
        continue;
      }

      if (playersSnap.docs.length < 8) {
        await _addPlayerToRoom(doc.id, userId, displayName, photoUrl, avatarConfig);
        return doc.id;
      }
    }

    return null;
  }

  Future<void> _addPlayerToRoom(String roomId, String userId, String displayName, String? photoUrl, Map<String, dynamic> avatarConfig) async {
    final cleanName = _filterName(displayName);
    await _db.collection('rooms').doc(roomId).collection('players').doc(userId).set({
      'displayName': cleanName,
      'photoUrl': photoUrl,
      'avatarConfig': avatarConfig,
      'score': 0,
      'correctGuesses': 0,
      'hasGuessedCorrectly': false,
      'isOnline': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRoomSettings(
    String roomId, {
    int? yearRangeStart,
    int? yearRangeEnd,
    int? totalRounds,
    List<String>? selectedVibes,
    List<int>? selectedClipStages,
    bool? isPublic,
    bool? isPartyMode,
  }) async {
    final updates = <String, dynamic>{};
    if (yearRangeStart != null) updates['yearFrom'] = yearRangeStart;
    if (yearRangeEnd != null) updates['yearTo'] = yearRangeEnd;
    if (totalRounds != null) updates['totalRounds'] = totalRounds.clamp(1, 25);
    if (selectedVibes != null) updates['selectedVibes'] = selectedVibes;
    if (selectedClipStages != null) updates['selectedClipStages'] = selectedClipStages;
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (isPartyMode != null) updates['isPartyMode'] = isPartyMode;
    
    if (updates.isNotEmpty) {
      await _db.collection('rooms').doc(roomId).update(updates);
    }
  }

  Future<String?> joinRoom({
    required String code,
    required String userId,
    required String displayName,
    String? photoUrl,
    Map<String, dynamic> avatarConfig = const {},
  }) async {
    final snap = await _db
        .collection('rooms')
        .where('code', isEqualTo: code.toUpperCase())
        .where('status', whereIn: ['waiting', 'playing', 'roundEnded'])
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final roomDoc = snap.docs.first;
    final roomId = roomDoc.id;
    final data = roomDoc.data();

    // 🔒 Security: Check if player is banned from this room
    final banned = List<String>.from(data['bannedPlayers'] ?? []);
    if (banned.contains(userId)) {
      throw Exception('You have been kicked from this lobby and cannot rejoin.');
    }

    // Reset points/state for new join or re-join
    await _addPlayerToRoom(roomId, userId, displayName, photoUrl, avatarConfig);

    return roomId;
  }

  Future<void> joinRoomById({
    required String roomId,
    required String userId,
    required String displayName,
    String? photoUrl,
    Map<String, dynamic> avatarConfig = const {},
  }) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) throw Exception('Room not found.');

    final data = roomDoc.data()!;
    final banned = List<String>.from(data['bannedPlayers'] ?? []);
    if (banned.contains(userId)) {
      throw Exception('You have been kicked from this lobby.');
    }

    await _addPlayerToRoom(roomId, userId, displayName, photoUrl, avatarConfig);
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    
    try {
      // 1. Remove the player first
      await roomRef.collection('players').doc(userId).delete();

      // 2. Check remaining players to decide on room destruction or handover
      final playersSnap = await roomRef.collection('players').get();
      final remainingPlayers = playersSnap.docs;

      if (remainingPlayers.isEmpty) {
        // 🧨 Cleanup guesses and other subcollections BEFORE deleting the room
        // This ensures the host still has permission to delete these records
        final guesses = await roomRef.collection('guesses').get();
        if (guesses.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var d in guesses.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }

        // Now safe to delete the room
        await roomRef.delete();
      } else {
        // 👑 Check if the person who left was the host
        final roomDoc = await roomRef.get();
        if (roomDoc.exists) {
          final data = roomDoc.data()!;
          if (data['hostId'] == userId) {
            // Hand over to the person who has been in the room longest (first in list)
            final nextHostId = remainingPlayers.first.id;
            await roomRef.update({'hostId': nextHostId});
          }
        }
      }
    } catch (e) {
      debugPrint('Silent error during leaveRoom: $e');
      // We don't rethrow here to avoid blocking the UI navigation
    }
  }

  Future<void> kickPlayer(String roomId, String userId) async {
    final batch = _db.batch();
    
    // Remove from players
    batch.delete(_db.collection('rooms').doc(roomId).collection('players').doc(userId));
    
    // Add to ban list
    batch.update(_db.collection('rooms').doc(roomId), {
      'bannedPlayers': FieldValue.arrayUnion([userId]),
    });
    
    await batch.commit();
  }

  Future<void> handleHostHandover(String roomId) async {
    final playersSnap = await _db.collection('rooms').doc(roomId).collection('players').orderBy('joinedAt').get();
    if (playersSnap.docs.isNotEmpty) {
      final nextHostId = playersSnap.docs.first.id;
      await _db.collection('rooms').doc(roomId).update({'hostId': nextHostId});
    }
  }

  Future<void> startGame(String roomId) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final data = roomDoc.data()!;

    final vibes = List<String>.from(data['selectedVibes'] ?? ['Bollywood']);
    final totalRounds = (data['totalRounds'] as num?)?.toInt() ?? 10;
    final yearFrom = (data['yearFrom'] as num?)?.toInt() ?? 1950;
    final yearTo = (data['yearTo'] as num?)?.toInt() ?? 2020;
    final stages = List<int>.from(data['selectedClipStages'] ?? [2, 3, 5]);

    final List<Song> allSongs = [];
    for (final vibe in vibes) {
      final songs = await _itunes.fetchSongsForRoom(
        genre: vibe,
        yearFrom: yearFrom,
        yearTo: yearTo,
        count: (totalRounds / vibes.length).ceil() + 2,
      );
      allSongs.addAll(songs);
    }

    if (allSongs.isEmpty) {
      throw Exception('Could not find enough songs for the selected vibes and era.');
    }

    _songQueue[roomId] = List.from(allSongs)..shuffle(_rand);
    final first = _songQueue[roomId]!.first;

    await _db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'currentRound': 1,
      'currentSong': first.toMap(),
      'revealedSeconds': stages.first,
      'roundStartedAt': FieldValue.serverTimestamp(),
      'skipVotes': [],
      'isSkipped': false,
      'isPaused': false,
    });

    // 📣 Chat Announcement (Centered in the history widget later)
    await _sendAnnouncement(roomId, ' ROUND 1 IS STARTING ');
  }

  Future<void> _sendAnnouncement(String roomId, String text) async {
    await _db.collection('rooms').doc(roomId).collection('guesses').add({
      'userId': 'system',
      'displayName': 'Arena',
      'guess': text,
      'correct': false,
      'isAnnouncement': true, // 📣 New field
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> togglePause(String roomId, bool paused) async {
    await _db.collection('rooms').doc(roomId).update({'isPaused': paused});
    if (paused) {
      await _sendAnnouncement(roomId, 'Game has been PAUSED by host.');
    } else {
      await _sendAnnouncement(roomId, 'Game has been RESUMED.');
    }
  }

  Future<void> skipRound(String roomId) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final batch = _db.batch();
    batch.update(roomDoc.reference, {
      'status': 'roundEnded',
      'isSkipped': true,
    });

    // Rollback points for anyone who guessed correctly this round
    final playersSnap = await _db.collection('rooms').doc(roomId).collection('players').where('hasGuessedCorrectly', isEqualTo: true).get();
    for (final doc in playersSnap.docs) {
      final data = doc.data();
      final lastPoints = (data['lastPointsEarned'] as num?)?.toInt() ?? 0;
      batch.update(doc.reference, {
        'score': FieldValue.increment(-lastPoints),
        'correctGuesses': FieldValue.increment(-1),
        'lastPointsEarned': 0,
      });
    }

    await batch.commit();
  }

  Future<void> voteToSkip(String roomId, String userId) async {
    await _db.collection('rooms').doc(roomId).update({
      'skipVotes': FieldValue.arrayUnion([userId]),
    });
  }

  static int getRoundDurationForStage(int stage) {
    if (stage <= 2) return 10;
    if (stage <= 5) return 15;
    if (stage <= 8) return 20;
    return 30;
  }

  Future<GuessResult> submitGuess({
    required String roomId,
    required String userId,
    required String displayName,
    required String guess,
  }) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final room = Room.fromMap(roomDoc.id, roomDoc.data()!);

    final songData = room.currentSong;
    if (songData == null) return GuessResult.wrong;

    final playerDoc = await _db.collection('rooms').doc(roomId).collection('players').doc(userId).get();
    if (playerDoc.data()?['hasGuessedCorrectly'] == true) return GuessResult.correct;

    final title = songData['title'] as String? ?? '';
    final result = _scoring.checkGuess(guess: guess, title: title);
    final isCorrect = result == GuessResult.correct;

    await _db.collection('rooms').doc(roomId).collection('guesses').add({
      'userId': userId,
      'displayName': displayName,
      'guess': isCorrect ? '' : guess,
      'correct': isCorrect,
      'roundNumber': room.currentRound,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (isCorrect) {
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

      final difficulty = songData['difficulty'] as String? ?? 'medium';
      final bool isHard = difficulty == 'hard' || difficulty == 'hardcore';

      await _db.collection('rooms').doc(roomId).collection('players').doc(userId).update({
        'score': FieldValue.increment(points),
        'correctGuesses': FieldValue.increment(1),
        'hasGuessedCorrectly': true,
        'lastPointsEarned': points,
        'totalElapsedMs': FieldValue.increment(elapsedMs),
        'hardCorrectGuesses': FieldValue.increment(isHard ? 1 : 0),
      });
    }

    return result;
  }

  Future<void> revealMoreClip(String roomId, int seconds) async {
    await _db.collection('rooms').doc(roomId).update({'revealedSeconds': seconds});
  }

  Future<void> forceEndRoundIfActive(String roomId) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    final data = roomDoc.data();
    if (data == null) return;
    if (data['status'] != 'playing') return;

    await _db.collection('rooms').doc(roomId).update({'status': 'roundEnded'});
  }

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
      final vibes = List<String>.from(data['selectedVibes'] ?? ['Bollywood']);
      
      final List<Song> allSongs = [];
      for (final vibe in vibes) {
        final songs = await _itunes.fetchSongsForRoom(
          genre: vibe,
          yearFrom: (data['yearFrom'] as num?)?.toInt() ?? 1950,
          yearTo: (data['yearTo'] as num?)?.toInt() ?? 2020,
          count: room.totalRounds,
        );
        allSongs.addAll(songs);
      }
      
      if (allSongs.isNotEmpty) {
        _songQueue[roomId] = List.from(allSongs)..shuffle(_rand);
        nextSong = _songQueue[roomId]!.first;
      }
    }

    final playersSnap = await _db.collection('rooms').doc(roomId).collection('players').get();
    final batch = _db.batch();
    for (final doc in playersSnap.docs) {
      batch.update(doc.reference, {
        'hasGuessedCorrectly': false,
        'lastPointsEarned': 0,
      });
    }
    await batch.commit();

    await _db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'currentRound': room.currentRound + 1,
      'currentSong': nextSong?.toMap(),
      'revealedSeconds': room.selectedClipStages.first,
      'roundStartedAt': FieldValue.serverTimestamp(),
      'skipVotes': [],
      'isSkipped': false,
      'isPaused': false,
    });

    // 📣 Chat Announcement
    await _sendAnnouncement(roomId, ' ROUND ${room.currentRound + 1} IS STARTING ');
  }

  Future<void> resetRoomForRematch(String roomId, String newHostId) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    final roomDoc = await roomRef.get();
    
    if (!roomDoc.exists) {
      throw 'This Arena no longer exists.';
    }
    
    final data = roomDoc.data()!;
    final stages = List<int>.from(data['selectedClipStages'] ?? [2, 3, 5]);

    // 1. Reset all players first (Batch)
    final playersSnap = await roomRef.collection('players').get();
    final batch = _db.batch();
    for (final doc in playersSnap.docs) {
      batch.update(doc.reference, {
        'score': 0,
        'correctGuesses': 0,
        'hasGuessedCorrectly': false,
        'lastPointsEarned': 0,
      });
    }

    // 2. Reset the room and assign new host
    batch.update(roomRef, {
      'status': 'waiting',
      'hostId': newHostId,
      'currentRound': 0,
      'currentSong': null,
      'revealedSeconds': stages.isNotEmpty ? stages.first : 3,
      'roundStartedAt': null,
      'skipVotes': [],
      'isSkipped': false,
      'isPaused': false,
      'startCountdown': 0,
    });

    await batch.commit();
  }

  Future<void> updateStartCountdown(String roomId, int value) async {
    await _db.collection('rooms').doc(roomId).update({'startCountdown': value});
  }

  /// 🧨 DEV ONLY: Purge all existing rooms and their subcollections
  Future<void> nukeAllRooms() async {
    final rooms = await _db.collection('rooms').get();
    for (final room in rooms.docs) {
      // Cleanup subcollections
      final players = await room.reference.collection('players').get();
      final guesses = await room.reference.collection('guesses').get();
      
      final batch = _db.batch();
      for (var p in players.docs) batch.delete(p.reference);
      for (var g in guesses.docs) batch.delete(g.reference);
      batch.delete(room.reference);
      await batch.commit();
    }
  }

  Future<void> updatePlayerDisplayName(String roomId, String userId, String newName) async {
    final cleanName = _filterName(newName);
    await _db.collection('rooms').doc(roomId).collection('players').doc(userId).update({
      'displayName': cleanName,
    });
  }

  Future<void> updateReadyStatus(String roomId, String userId, bool isReady) async {
    await _db.collection('rooms').doc(roomId).collection('players').doc(userId).update({
      'isReady': isReady,
    });
  }

  Future<void> updateTypingStatus(String roomId, String userId, bool isTyping) async {
    await _db.collection('rooms').doc(roomId).collection('players').doc(userId).update({
      'isTyping': isTyping,
    });
  }

  String _filterName(String name) {
    final explicitWords = ['nigga', 'cock', 'faggot', 'nigger', 'rape', 'porn'];
    String filtered = name;
    for (var word in explicitWords) {
      final regExp = RegExp(word, caseSensitive: false);
      filtered = filtered.replaceAll(regExp, '*' * word.length);
    }
    return filtered;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
  }
}
