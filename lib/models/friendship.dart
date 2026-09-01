import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendshipStatus { pending, accepted }

class Friendship {
  final String id;
  final List<String> userIds;
  final String requestedBy;
  final FriendshipStatus status;
  final DateTime createdAt;
  final bool isRead; // 🔔 New field

  Friendship({
    required this.id,
    required this.userIds,
    required this.requestedBy,
    required this.status,
    required this.createdAt,
    this.isRead = false,
  });

  factory Friendship.fromMap(String id, Map<String, dynamic> map) {
    return Friendship(
      id: id,
      userIds: List<String>.from(map['userIds'] ?? []),
      requestedBy: map['requestedBy'] ?? '',
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'userIds': userIds,
    'requestedBy': requestedBy,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'isRead': isRead,
  };

  String getOtherId(String myUid) {
    return userIds.firstWhere((uid) => uid != myUid, orElse: () => '');
  }
}
