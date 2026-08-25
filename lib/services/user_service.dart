import 'dart:async';
import 'dart:convert';
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
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
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
        
        debugPrint('Cloudinary upload success: $secureUrl');
        
        // Optimize the image for fast loading as a 200x200 square.
        // Since we already cropped to 1:1 in-app, c_fill will just resize it perfectly.
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final transformedUrl = secureUrl.replaceFirst('/upload/', '/upload/w_200,h_200,c_fill/') + '?t=$timestamp';
        
        await updateUser(uid, {'photoUrl': transformedUrl});
        return transformedUrl;
      } else {
        debugPrint('Cloudinary upload failed: $responseData');
        throw Exception('Cloudinary upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('!!! uploadProfileImage failed: $e');
      rethrow;
    }
  }

  Future<bool> isPhoneNumberUnique(String phoneNumber) async {
    try {
      final snap = await _db.collection('users').where('phoneNumber', isEqualTo: phoneNumber).limit(1).get();
      return snap.docs.isEmpty;
    } catch (e) {
      debugPrint('Warning: Could not verify phone uniqueness due to permissions. Ensure "list" rules are set for users collection.');
      // Fallback: assume unique and let Firebase Auth handle conflicts during linking
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
}
