import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus { waiting, playing, roundEnded, finished }

class Room {
  final String id;
  final String hostId;
  final String code;
  final RoomStatus status;
  final int currentRound;
  final int totalRounds;
  final Map<String, dynamic>? currentSong;
  final String? difficulty;
  final int revealedSeconds;
  final Timestamp? roundStartedAt;
  final String? language;
  final String? genre;
  final int yearFrom;
  final int yearTo;

  const Room({
    required this.id,
    required this.hostId,
    required this.code,
    required this.status,
    required this.currentRound,
    required this.totalRounds,
    this.currentSong,
    this.difficulty,
    required this.revealedSeconds,
    this.roundStartedAt,
    this.language,
    this.genre,
    this.yearFrom = 1950,
    this.yearTo = 2020,
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
      currentSong: d['currentSong'] as Map<String, dynamic>?,
      difficulty:  d['difficulty']  as String?,
      revealedSeconds: (d['revealedSeconds'] as num?)?.toInt() ?? 3,
      roundStartedAt: d['roundStartedAt'] as Timestamp?,
      language: d['language'] as String?,
      genre: d['genre'] as String?,
      yearFrom: (d['yearFrom'] as num?)?.toInt() ?? 1950,
      yearTo: (d['yearTo'] as num?)?.toInt() ?? 2020,
    );
  }

  Map<String, dynamic> toMap() => {
    'hostId': hostId,
    'code': code,
    'status': status.name,
    'currentRound': currentRound,
    'totalRounds': totalRounds,
    'currentSong': currentSong,
    'difficulty':  difficulty,
    'revealedSeconds': revealedSeconds,
    if (roundStartedAt != null) 'roundStartedAt': roundStartedAt,
    if (language != null) 'language': language,
    if (genre != null) 'genre': genre,
    'yearFrom': yearFrom,
    'yearTo': yearTo,
  };

  Room copyWith({
    RoomStatus? status,
    int? currentRound,
    int? totalRounds,
    Map<String, dynamic>? currentSong,
    int? revealedSeconds,
    Timestamp? roundStartedAt,
    String? language,
    String? genre,
    String? difficulty,
    int? yearFrom,
    int? yearTo,
  }) {
    return Room(
      id:              id,
      hostId:          hostId,
      code:            code,
      status:          status          ?? this.status,
      currentRound:    currentRound    ?? this.currentRound,
      totalRounds:     totalRounds     ?? this.totalRounds,
      currentSong:     currentSong     ?? this.currentSong,
      revealedSeconds: revealedSeconds ?? this.revealedSeconds,
      roundStartedAt:  roundStartedAt  ?? this.roundStartedAt,
      language:        language        ?? this.language,
      genre:           genre           ?? this.genre,
      difficulty:      difficulty      ?? this.difficulty,
      yearFrom:        yearFrom        ?? this.yearFrom,
      yearTo:          yearTo          ?? this.yearTo,
    );
  }
}