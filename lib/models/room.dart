import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus { waiting, playing, finished }

class Room {
  final String id;
  final String code;
  final String hostId;
  final RoomStatus status;
  final int currentRound;
  final int totalRounds;
  final String? currentSongId;
  final DateTime? roundStartTime;
  final int revealedSeconds; // 3, 5, or 10

  const Room({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.currentRound,
    required this.totalRounds,
    this.currentSongId,
    this.roundStartTime,
    required this.revealedSeconds,
  });

  factory Room.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Room(
      id: doc.id,
      code: d['code'],
      hostId: d['hostId'],
      status: RoomStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => RoomStatus.waiting,
      ),
      currentRound: d['currentRound'] ?? 0,
      totalRounds: d['totalRounds'] ?? 5,
      currentSongId: d['currentSongId'],
      roundStartTime: (d['roundStartTime'] as Timestamp?)?.toDate(),
      revealedSeconds: d['revealedSeconds'] ?? 3,
    );
  }
}