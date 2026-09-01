import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AvatarConfig {
  final Color bodyColor;
  final int eyeType;
  final int mouthType;

  AvatarConfig({
    required this.bodyColor,
    required this.eyeType,
    required this.mouthType,
  });

  factory AvatarConfig.random() {
    final rand = Random();
    final colors = [
      Colors.blue, Colors.green, Colors.red, Colors.yellow,
      Colors.orange, Colors.purple, Colors.pink, Colors.cyan,
    ];
    return AvatarConfig(
      bodyColor: colors[rand.nextInt(colors.length)],
      eyeType: rand.nextInt(4),
      mouthType: rand.nextInt(4),
    );
  }

  factory AvatarConfig.fromMap(Map<String, dynamic> map) {
    return AvatarConfig(
      bodyColor: Color(map['bodyColor'] ?? Colors.blue.value),
      eyeType: (map['eyeType'] as num?)?.toInt() ?? 0,
      mouthType: (map['mouthType'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'bodyColor': bodyColor.value,
    'eyeType': eyeType,
    'mouthType': mouthType,
  };
}

class UserStats {
  final int gamesPlayed;
  final int totalPoints;
  final int wins;
  final List<int> rankHistory;

  const UserStats({
    this.gamesPlayed = 0,
    this.totalPoints = 0,
    this.wins = 0,
    this.rankHistory = const [],
  });

  factory UserStats.fromMap(dynamic map) {
    if (map == null || map is! Map) return const UserStats();
    return UserStats(
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      rankHistory: map['rankHistory'] is List
          ? List<int>.from(map['rankHistory'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'gamesPlayed': gamesPlayed,
    'totalPoints': totalPoints,
    'wins': wins,
    'rankHistory': rankHistory,
  };

  UserStats copyWith({
    int? gamesPlayed,
    int? totalPoints,
    int? wins,
    List<int>? rankHistory,
  }) {
    return UserStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      totalPoints: totalPoints ?? this.totalPoints,
      wins: wins ?? this.wins,
      rankHistory: rankHistory ?? this.rankHistory,
    );
  }
}

class DailyStats {
  final int challengesPlayed;
  final int totalPoints;
  final int perfectScores; // 5/5 caught

  const DailyStats({
    this.challengesPlayed = 0,
    this.totalPoints = 0,
    this.perfectScores = 0,
  });

  factory DailyStats.fromMap(dynamic map) {
    if (map == null || map is! Map) return const DailyStats();
    return DailyStats(
      challengesPlayed: (map['challengesPlayed'] as num?)?.toInt() ?? 0,
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
      perfectScores: (map['perfectScores'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'challengesPlayed': challengesPlayed,
    'totalPoints': totalPoints,
    'perfectScores': perfectScores,
  };
}

class AppUser {
  final String uid;
  final String displayName;
  final String catcherId; // 🆔 Unique ID (e.g. SONGCATCHER#4921)
  final String? photoUrl;
  final String? email;
  final String? phoneNumber;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final Map<String, dynamic> avatarConfig;
  final UserStats arenaStats;
  final DailyStats dailyStats;
  final int musCoins;
  final bool isOnline; // 🟢 Online status
  final String currentActivity; // 🆕 Activity status
  final DateTime lastSeen; // ⏱️ Activity tracking
  final DateTime createdAt;
  final DateTime? lastReadGlobalNotificationAt; // 🔔 New field

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.catcherId,
    this.photoUrl,
    this.email,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.avatarConfig = const {},
    this.arenaStats = const UserStats(),
    this.dailyStats = const DailyStats(),
    this.musCoins = 0,
    this.isOnline = false,
    this.currentActivity = 'Home',
    required this.lastSeen,
    required this.createdAt,
    this.lastReadGlobalNotificationAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final rawArena = map['arenaStats'] ?? map['stats'];
    final rawDaily = map['dailyStats'];
    final rawAvatar = map['avatarConfig'];

    return AppUser(
      uid: uid,
      displayName: map['displayName'] ?? 'Player',
      catcherId: map['catcherId'] ?? 'CATCHER#0000',
      photoUrl: map['photoUrl'],
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      isEmailVerified: map['isEmailVerified'] ?? false,
      isPhoneVerified: map['isPhoneVerified'] ?? false,
      avatarConfig: (rawAvatar is Map) 
          ? Map<String, dynamic>.from(rawAvatar) 
          : AvatarConfig.random().toMap(),
      arenaStats: UserStats.fromMap(rawArena),
      dailyStats: DailyStats.fromMap(rawDaily),
      musCoins: (map['musCoins'] as num?)?.toInt() ?? 0,
      isOnline: map['isOnline'] ?? false,
      currentActivity: map['currentActivity'] ?? 'Home',
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReadGlobalNotificationAt: (map['lastReadGlobalNotificationAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'catcherId': catcherId,
    'photoUrl': photoUrl,
    'email': email,
    'phoneNumber': phoneNumber,
    'isEmailVerified': isEmailVerified,
    'isPhoneVerified': isPhoneVerified,
    'avatarConfig': avatarConfig,
    'arenaStats': arenaStats.toMap(),
    'dailyStats': dailyStats.toMap(),
    'musCoins': musCoins,
    'isOnline': isOnline,
    'currentActivity': currentActivity,
    'lastSeen': Timestamp.fromDate(lastSeen),
    'createdAt': Timestamp.fromDate(createdAt),
    if (lastReadGlobalNotificationAt != null)
      'lastReadGlobalNotificationAt': Timestamp.fromDate(lastReadGlobalNotificationAt!),
  };

  AppUser copyWith({
    String? displayName,
    String? catcherId,
    String? photoUrl,
    String? email,
    String? phoneNumber,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    Map<String, dynamic>? avatarConfig,
    UserStats? arenaStats,
    DailyStats? dailyStats,
    int? musCoins,
    bool? isOnline,
    String? currentActivity,
    DateTime? lastSeen,
    DateTime? lastReadGlobalNotificationAt,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      catcherId: catcherId ?? this.catcherId,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      arenaStats: arenaStats ?? this.arenaStats,
      dailyStats: dailyStats ?? this.dailyStats,
      musCoins: musCoins ?? this.musCoins,
      isOnline: isOnline ?? this.isOnline,
      currentActivity: currentActivity ?? this.currentActivity,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
      lastReadGlobalNotificationAt: lastReadGlobalNotificationAt ?? this.lastReadGlobalNotificationAt,
    );
  }
}
