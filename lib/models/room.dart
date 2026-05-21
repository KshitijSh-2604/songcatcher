import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus { waiting, playing, finished }

class Room {
  final String id;
  final String hostId;
  final String code;
  final RoomStatus status;
  final int currentRound;
  final int totalRounds;
  final String? currentSongId;
  final int revealedSeconds;
  final List<String> songPool;
  final List<String> playedSongIds;
  final Timestamp? roundStartedAt;   // ← added
  final String? language;            // ← added (optional filter)
  final String? genre;               // ← added (optional filter)

  const Room({
    required this.id,
    required this.hostId,
    required this.code,
    required this.status,
    required this.currentRound,
    required this.totalRounds,
    this.currentSongId,
    required this.revealedSeconds,
    required this.songPool,
    required this.playedSongIds,
    this.roundStartedAt,
    this.language,
    this.genre,
  });

  factory Room.fromMap(String id, Map<String, dynamic> d) {
    return Room(
      id: id,
      hostId: d['hostId'] ?? '',
      code: d['code'] ?? '',
      status: RoomStatus.values.firstWhere(
            (s) => s.name == d['status'],
        orElse: () => RoomStatus.waiting,
      ),
      currentRound: (d['currentRound'] as num?)?.toInt() ?? 0,
      totalRounds: (d['totalRounds'] as num?)?.toInt() ?? 10,
      currentSongId: d['currentSongId'] as String?,
      revealedSeconds: (d['revealedSeconds'] as num?)?.toInt() ?? 3,
      songPool: List<String>.from(d['songPool'] ?? []),
      playedSongIds: List<String>.from(d['playedSongIds'] ?? []),
      roundStartedAt: d['roundStartedAt'] as Timestamp?,
      language: d['language'] as String?,
      genre: d['genre'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'hostId': hostId,
    'code': code,
    'status': status.name,
    'currentRound': currentRound,
    'totalRounds': totalRounds,
    'currentSongId': currentSongId,
    'revealedSeconds': revealedSeconds,
    'songPool': songPool,
    'playedSongIds': playedSongIds,
    if (roundStartedAt != null) 'roundStartedAt': roundStartedAt,
    if (language != null) 'language': language,
    if (genre != null) 'genre': genre,
  };

  Room copyWith({
    RoomStatus? status,
    int? currentRound,
    String? currentSongId,
    int? revealedSeconds,
    List<String>? songPool,
    List<String>? playedSongIds,
    Timestamp? roundStartedAt,
    String? language,
    String? genre,
  }) {
    return Room(
      id: id,
      hostId: hostId,
      code: code,
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds,
      currentSongId: currentSongId ?? this.currentSongId,
      revealedSeconds: revealedSeconds ?? this.revealedSeconds,
      songPool: songPool ?? this.songPool,
      playedSongIds: playedSongIds ?? this.playedSongIds,
      roundStartedAt: roundStartedAt ?? this.roundStartedAt,
      language: language ?? this.language,
      genre: genre ?? this.genre,
    );
  }
}