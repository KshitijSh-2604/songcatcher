import 'package:cloud_firestore/cloud_firestore.dart';
import 'song.dart';

class DailyChallenge {
  final String id; // date_vibe
  final String date;
  final String vibe;
  final List<Song> songs;
  final DateTime createdAt;

  DailyChallenge({
    required this.id,
    required this.date,
    required this.vibe,
    required this.songs,
    required this.createdAt,
  });

  factory DailyChallenge.fromMap(String id, Map<String, dynamic> map) {
    return DailyChallenge(
      id: id,
      date: map['date'] ?? '',
      vibe: map['vibe'] ?? '',
      songs: (map['songs'] as List? ?? [])
          .map((s) => Song.fromMap(s as Map<String, dynamic>))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    'vibe': vibe,
    'songs': songs.map((s) => s.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class DailyAttempt {
  final String id; // date_vibe_userId
  final String userId;
  final String displayName;
  final String? photoUrl;
  final Map<String, dynamic> avatarConfig;
  final String date;
  final String vibe;
  final int score;
  final int correctCount;
  final int totalTimeMs;
  final int totalTries;
  final bool completed;
  final DateTime updatedAt;

  DailyAttempt({
    required this.id,
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.avatarConfig = const {},
    required this.date,
    required this.vibe,
    this.score = 0,
    this.correctCount = 0,
    this.totalTimeMs = 0,
    this.totalTries = 0,
    this.completed = false,
    required this.updatedAt,
  });

  factory DailyAttempt.fromMap(String id, Map<String, dynamic> map) {
    return DailyAttempt(
      id: id,
      userId: map['userId'] ?? '',
      displayName: map['displayName'] ?? 'Player',
      photoUrl: map['photoUrl'],
      avatarConfig: Map<String, dynamic>.from(map['avatarConfig'] ?? {}),
      date: map['date'] ?? '',
      vibe: map['vibe'] ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      correctCount: (map['correctCount'] as num?)?.toInt() ?? 0,
      totalTimeMs: (map['totalTimeMs'] as num?)?.toInt() ?? 0,
      totalTries: (map['totalTries'] as num?)?.toInt() ?? 0,
      completed: map['completed'] ?? false,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'avatarConfig': avatarConfig,
    'date': date,
    'vibe': vibe,
    'score': score,
    'correctCount': correctCount,
    'totalTimeMs': totalTimeMs,
    'totalTries': totalTries,
    'completed': completed,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
