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
  final List<String> selectedVibes;
  final List<int> selectedClipStages;
  final int yearFrom;
  final int yearTo;
  final bool isPublic;
  final List<String> skipVotes;
  final bool isSkipped;
  final int startCountdown;
  final bool isPartyMode;
  final bool isPaused; // ⏸️ New field
  final bool forceLockVisibility;

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
    this.selectedVibes = const ['Bollywood'],
    this.selectedClipStages = const [2, 3, 5],
    this.yearFrom = 1950,
    this.yearTo = 2030,
    this.isPublic = false,
    this.skipVotes = const [],
    this.isSkipped = false,
    this.startCountdown = 0,
    this.isPartyMode = false,
    this.isPaused = false,
    this.forceLockVisibility = false,
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
      selectedVibes: List<String>.from(d['selectedVibes'] ?? ['Bollywood']),
      selectedClipStages: List<int>.from(d['selectedClipStages'] ?? [2, 3, 5]),
      yearFrom: (d['yearFrom'] as num?)?.toInt() ?? 1950,
      yearTo: (d['yearTo'] as num?)?.toInt() ?? 2030,
      isPublic: d['isPublic'] ?? false,
      skipVotes: List<String>.from(d['skipVotes'] ?? []),
      isSkipped: d['isSkipped'] ?? false,
      startCountdown: (d['startCountdown'] as num?)?.toInt() ?? 0,
      isPartyMode: d['isPartyMode'] ?? false,
      isPaused: d['isPaused'] ?? false,
      forceLockVisibility: d['forceLockVisibility'] ?? false,
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
    'selectedVibes': selectedVibes,
    'selectedClipStages': selectedClipStages,
    'yearFrom': yearFrom,
    'yearTo': yearTo,
    'isPublic': isPublic,
    'skipVotes': skipVotes,
    'isSkipped': isSkipped,
    'startCountdown': startCountdown,
    'isPartyMode': isPartyMode,
    'isPaused': isPaused,
    'forceLockVisibility': forceLockVisibility,
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
    List<String>? selectedVibes,
    List<int>? selectedClipStages,
    String? difficulty,
    int? yearFrom,
    int? yearTo,
    bool? isPublic,
    String? hostId,
    List<String>? skipVotes,
    bool? isSkipped,
    int? startCountdown,
    bool? isPartyMode,
    bool? isPaused,
    bool? forceLockVisibility,
  }) {
    return Room(
      id:              id,
      hostId:          hostId          ?? this.hostId,
      code:            code,
      status:          status          ?? this.status,
      currentRound:    currentRound    ?? this.currentRound,
      totalRounds:     totalRounds     ?? this.totalRounds,
      currentSong:     currentSong     ?? this.currentSong,
      revealedSeconds: revealedSeconds ?? this.revealedSeconds,
      roundStartedAt:  roundStartedAt  ?? this.roundStartedAt,
      language:        language        ?? this.language,
      genre:           genre           ?? this.genre,
      selectedVibes:   selectedVibes   ?? this.selectedVibes,
      selectedClipStages: selectedClipStages ?? this.selectedClipStages,
      difficulty:      difficulty      ?? this.difficulty,
      yearFrom:        yearFrom        ?? this.yearFrom,
      yearTo:          yearTo          ?? this.yearTo,
      isPublic:        isPublic        ?? this.isPublic,
      skipVotes:       skipVotes       ?? this.skipVotes,
      isSkipped:       isSkipped       ?? this.isSkipped,
      startCountdown:  startCountdown  ?? this.startCountdown,
      isPartyMode:     isPartyMode     ?? this.isPartyMode,
      isPaused:        isPaused        ?? this.isPaused,
      forceLockVisibility: forceLockVisibility ?? this.forceLockVisibility,
    );
  }
}
