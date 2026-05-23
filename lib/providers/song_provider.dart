import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/room.dart';

/// Extracts the current song from a Room object.
/// No Firestore songs collection needed — song data lives in the room document.
final currentSongProvider = Provider.autoDispose.family<Song?, Room?>((ref, room) {
  if (room == null) return null;
  final data = room.currentSong;
  if (data == null) return null;
  return Song.fromMap(data);
});

/// Difficulty label + colour info for the current room's selected difficulty.
final difficultyInfoProvider =
Provider.autoDispose.family<({String label, String emoji}), String?>(
      (ref, difficulty) {
    return switch (difficulty) {
      'easy'     => (label: 'Easy',     emoji: '🟢'),
      'medium'   => (label: 'Medium',   emoji: '🟡'),
      'hard'     => (label: 'Hard',     emoji: '🔴'),
      'hardcore' => (label: 'Hardcore', emoji: '💀'),
      _          => (label: 'Mixed',    emoji: '🎵'),
    };
  },
);