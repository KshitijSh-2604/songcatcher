import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';

final _db = FirebaseFirestore.instance;

/// Fetches a single song by ID (cached with autoDispose.family)
final songProvider =
FutureProvider.autoDispose.family<Song?, String>((ref, songId) async {
  if (songId.isEmpty) return null;

  final doc = await _db.collection('songs').doc(songId).get();
  if (!doc.exists) return null;

  return Song.fromMap(doc.id, doc.data()!);
});

/// Fetches all songs matching language + decade filters
final filteredSongsProvider = FutureProvider.autoDispose
    .family<List<Song>, ({String? language, String? decade})>(
        (ref, filters) async {
      Query query = _db.collection('songs');

      if (filters.language != null) {
        query = query.where('language', isEqualTo: filters.language);
      }
      if (filters.decade != null) {
        query = query.where('decade', isEqualTo: filters.decade);
      }

      final snap = await query.limit(100).get();
      return snap.docs
          .map((d) => Song.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
    });

/// Count of songs matching filters (shown in lobby)
final songCountProvider = FutureProvider.autoDispose
    .family<int, ({String? language, String? decade})>(
        (ref, filters) async {
      final songs = await ref.watch(filteredSongsProvider(filters).future);
      return songs.length;
    });