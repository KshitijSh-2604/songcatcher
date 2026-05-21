import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player.dart';
import '../models/room.dart';

final _db = FirebaseFirestore.instance;

/// Live stream of a single room document
final roomProvider =
StreamProvider.family<Room?, String>((ref, roomId) {
  return _db
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((snap) {
    if (!snap.exists) return null;
    return Room.fromMap(snap.id, snap.data()!);
  });
});

/// Live stream of all players in a room, sorted by score descending
final playersProvider =
StreamProvider.family<List<Player>, String>((ref, roomId) {
  return _db
      .collection('rooms')
      .doc(roomId)
      .collection('players')
      .orderBy('score', descending: true)
      .snapshots()
      .map((snap) => snap.docs
      .map((d) => Player.fromMap(d.id, d.data()))
      .toList());
});

/// Live stream of guesses for a specific player in a room
final playerGuessesProvider =
StreamProvider.family<List<Map<String, dynamic>>, ({String roomId, String userId})>(
        (ref, args) {
      return _db
          .collection('rooms')
          .doc(args.roomId)
          .collection('guesses')
          .where('userId', isEqualTo: args.userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map((snap) =>
          snap.docs.map((d) => d.data()).toList());
    });

/// Live stream of all guesses in a room (for host view / reveal)
final allGuessesProvider =
StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, roomId) {
      return _db
          .collection('rooms')
          .doc(roomId)
          .collection('guesses')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snap) =>
          snap.docs.map((d) => d.data()).toList());
    });

/// Derives the current player's data from the players stream
final myPlayerProvider =
Provider.family<Player?, ({String roomId, String userId})>(
        (ref, args) {
      final players =
          ref.watch(playersProvider(args.roomId)).valueOrNull ?? [];
      try {
        return players.firstWhere((p) => p.id == args.userId);
      } catch (_) {
        return null;
      }
    });

/// True if the current user has already guessed correctly this round
final hasGuessedCorrectlyProvider =
Provider.family<bool, ({String roomId, String userId})>(
        (ref, args) {
      final player = ref.watch(myPlayerProvider(args));
      return player?.hasGuessedCorrectly ?? false;
    });