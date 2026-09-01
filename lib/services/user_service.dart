// UserService handles database operations for user profiles and identity.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/app_user.dart';

class UserService {
  final _db = FirebaseFirestore.instance;
  
  static const _cloudinaryCloudName = 'werxhn5h';
  static const _cloudinaryUploadPreset = 'songcatcher';

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromMap(snap.id, snap.data()!);
    });
  }

  Future<void> createUser(AppUser user) async {
    final cleanDisplayName = _filterName(user.displayName);
    String finalCatcherId = user.catcherId;
    
    if (finalCatcherId == 'CATCHER#0000') {
      finalCatcherId = await generateUniqueCatcherId();
    }

    final cleanUser = user.copyWith(
      displayName: cleanDisplayName,
      catcherId: finalCatcherId,
      isOnline: true,
      lastSeen: DateTime.now(),
    );
    await _db.collection('users').doc(user.uid).set(cleanUser.toMap());
  }

  Future<void> updateOnlineStatus(String uid, bool isOnline, {String? activity}) async {
    await _db.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
      if (activity != null) 'currentActivity': activity,
    });
  }

  Future<void> updateActivity(String uid, String activity) async {
    await _db.collection('users').doc(uid).update({
      'currentActivity': activity,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<String> generateUniqueCatcherId() async {
    final rand = Random();
    while (true) {
      final num = rand.nextInt(9000) + 1000; // 1000-9999
      final id = 'CATCHER#$num';
      final snap = await _db.collection('users').where('catcherId', isEqualTo: id).limit(1).get();
      if (snap.docs.isEmpty) return id;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    if (cleanData.containsKey('displayName')) {
      cleanData['displayName'] = _filterName(cleanData['displayName'] as String);
    }
    await _db.collection('users').doc(uid).set(cleanData, SetOptions(merge: true));
  }

  String _filterName(String name) {
    final explicitWords = ['nigga', 'cock', 'faggot', 'nigger', 'rape', 'porn'];
    String filtered = name;
    for (var word in explicitWords) {
      final regExp = RegExp(word, caseSensitive: false);
      filtered = filtered.replaceAll(regExp, '*' * word.length);
    }
    return filtered;
  }

  Future<String?> uploadProfileImage(String uid, Uint8List bytes) async {
    try {
      debugPrint('Uploading image to Cloudinary for $uid... (${bytes.length} bytes)');
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..fields['public_id'] = 'user_profile_$uid'
        ..fields['folder'] = 'users/$uid'
        ..fields['overwrite'] = 'true'
        ..fields['invalidate'] = 'true'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'profile.jpg'));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(responseData);
        final secureUrl = json['secure_url'] as String;
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
      final transformedUrl = secureUrl.replaceFirst('/upload/', '/upload/w_200,h_200,c_fill/') + '?t=$timestamp';
      
      await updateUser(uid, {'photoUrl': transformedUrl});
      return transformedUrl;
    } else {
      throw Exception('Cloudinary upload failed');
    }
  } catch (e) {
    rethrow;
  }
}

  Future<bool> isPhoneNumberUnique(String phoneNumber) async {
    try {
      final snap = await _db.collection('users').where('phoneNumber', isEqualTo: phoneNumber).limit(1).get();
      return snap.docs.isEmpty;
    } catch (e) {
      debugPrint('Warning: Could not verify phone uniqueness due to permissions.');
      return true;
    }
  }

  Future<bool> isEmailUnique(String email) async {
    try {
      final snap = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
      return snap.docs.isEmpty;
    } catch (e) {
      debugPrint('Warning: Could not verify email uniqueness due to permissions.');
      return true;
    }
  }

  Future<void> randomizeAvatar(String uid) async {
    final newConfig = AvatarConfig.random();
    await updateUser(uid, {'avatarConfig': newConfig.toMap()});
  }

  Future<void> removeProfileImage(String uid) async {
    await updateUser(uid, {'photoUrl': null});
  }

  Future<void> recordGameResult(String uid, {required int points, required int rank}) async {
    final user = await getUser(uid);
    if (user == null) return;

    final newArenaStats = user.arenaStats.copyWith(
      gamesPlayed: user.arenaStats.gamesPlayed + 1,
      totalPoints: user.arenaStats.totalPoints + points,
      wins: user.arenaStats.wins + (rank == 1 ? 1 : 0),
      rankHistory: [...user.arenaStats.rankHistory, rank].take(20).toList(),
    );

    await updateUser(uid, {'arenaStats': newArenaStats.toMap()});
  }

  Future<List<AppUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    if (query.toUpperCase().startsWith('CATCHER#')) {
      final snap = await _db.collection('users')
          .where('catcherId', isEqualTo: query.toUpperCase())
          .limit(1)
          .get();
      return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
    }

    final snap = await _db.collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(10)
        .get();
        
    return snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
  }

  // ── Global System Notifications ──────────────────────────────────────────

  Future<void> sendGlobalNotification({
    required String title,
    required String body,
    required String senderName,
  }) async {
    await _db.collection('global_notifications').add({
      'title': title,
      'body': body,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchGlobalNotifications() {
    return _db.collection('global_notifications')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> updateLastReadGlobalNotification(String uid) async {
    await updateUser(uid, {
      'lastReadGlobalNotificationAt': FieldValue.serverTimestamp(),
    });
  }
}
