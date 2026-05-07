import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../models/player.dart';

final roomProvider = StreamProvider.family<Room?, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((snap) => snap.exists ? Room.fromDoc(snap) : null);
});

final playersProvider = StreamProvider.family<List<Player>, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .collection('players')
      .snapshots()
      .map((snap) => snap.docs
      .map((d) => Player.fromMap(d.id, d.data()))
      .toList()
    ..sort((a, b) => b.score.compareTo(a.score)));
});

final myGuessesProvider = StreamProvider.family<List<Map<String, dynamic>>, ({String roomId, String userId})>(
      (ref, args) {
    return FirebaseFirestore.instance
        .collection('rooms')
        .doc(args.roomId)
        .collection('guesses')
        .doc(args.userId)
        .collection('attempts')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  },
);