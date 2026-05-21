import 'package:cloud_firestore/cloud_firestore.dart';

class Guess {
  final String userId;
  final String displayName;
  final String guess;
  final bool correct;
  final DateTime timestamp;
  final int roundNumber;

  const Guess({
    required this.userId,
    required this.displayName,
    required this.guess,
    required this.correct,
    required this.timestamp,
    required this.roundNumber,
  });

  factory Guess.fromMap(Map<String, dynamic> d) {
    return Guess(
      userId: d['userId'] ?? '',
      displayName: d['displayName'] ?? '',
      guess: d['guess'] ?? '',
      correct: d['correct'] ?? false,
      timestamp:
      (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roundNumber: d['roundNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'guess': guess,
    'correct': correct,
    'timestamp': Timestamp.fromDate(timestamp),
    'roundNumber': roundNumber,
  };
}