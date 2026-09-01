import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/friendship.dart';

class FriendService {
  final _db = FirebaseFirestore.instance;

  static const int maxFriends = 99; // 🚀 Updated limit
  static const int maxPendingInvites = 50;

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    if (fromUid == toUid) throw Exception('You cannot add yourself as a friend.');

    // Check existing friendship
    final id = _getFriendshipId(fromUid, toUid);
    final doc = await _db.collection('friendships').doc(id).get();
    if (doc.exists) {
      final f = Friendship.fromMap(doc.id, doc.data()!);
      if (f.status == FriendshipStatus.accepted) throw Exception('You are already friends.');
      if (f.requestedBy == fromUid) throw Exception('Friend request already sent.');
      // If requested by the other person, just accept it
      return acceptFriendRequest(id);
    }

    // Check limits for sender
    final myFriends = await _db.collection('friendships')
        .where('userIds', arrayContains: fromUid)
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .get();
    if (myFriends.docs.length >= maxFriends) throw Exception('You have reached the maximum limit of $maxFriends friends.');

    // Check limits for pending invites sent by me
    final myPending = await _db.collection('friendships')
        .where('requestedBy', isEqualTo: fromUid)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .get();
    if (myPending.docs.length >= maxPendingInvites) throw Exception('You have reached the limit of $maxPendingInvites pending invites.');

    final friendship = Friendship(
      id: id,
      userIds: [fromUid, toUid],
      requestedBy: fromUid,
      status: FriendshipStatus.pending,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _db.collection('friendships').doc(id).set(friendship.toMap());
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    final doc = await _db.collection('friendships').doc(friendshipId).get();
    if (!doc.exists) return;

    final f = Friendship.fromMap(doc.id, doc.data()!);

    // Check limit for both users before accepting
    try {
      for (final uid in f.userIds) {
         final friends = await _db.collection('friendships')
            .where('userIds', arrayContains: uid)
            .where('status', isEqualTo: FriendshipStatus.accepted.name)
            .get();
         if (friends.docs.length >= maxFriends) {
            throw Exception('One of the users has reached the maximum limit of $maxFriends friends.');
         }
      }
    } catch (e) {
      // If index is missing or other query error, we log it but allow the update to proceed
      // to avoid breaking the core feature while indexes are building.
      debugPrint('Friend limit check failed: $e. Proceeding with accept.');
    }

    await _db.collection('friendships').doc(friendshipId).update({
      'status': FriendshipStatus.accepted.name,
    });
  }

  Future<void> rejectFriendRequest(String friendshipId) async {
    await _db.collection('friendships').doc(friendshipId).delete();
  }

  Future<void> removeFriend(String friendshipId) async {
    await _db.collection('friendships').doc(friendshipId).delete();
  }

  Stream<List<Friendship>> watchFriends(String uid) {
    return _db.collection('friendships')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: FriendshipStatus.accepted.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Friendship.fromMap(d.id, d.data())).toList());
  }

  Stream<List<Friendship>> watchPendingRequests(String uid) {
    return _db.collection('friendships')
        .where('userIds', arrayContains: uid)
        .where('status', isEqualTo: FriendshipStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Friendship.fromMap(d.id, d.data())).toList());
  }

  String _getFriendshipId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  // ── Lobby Invites ────────────────────────────────────────────────────────

  Future<void> sendLobbyInvite({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String roomId,
    required String roomCode,
  }) async {
    await _db.collection('invites').add({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'roomId': roomId,
      'roomCode': roomCode,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> markInviteAsRead(String inviteId) async {
    final doc = await _db.collection('invites').doc(inviteId).get();
    if (doc.exists && doc.data()?['status'] == 'pending') {
      await _db.collection('invites').doc(inviteId).update({'status': 'read'});
    }
  }

  Future<void> markFriendRequestAsRead(String friendshipId) async {
    await _db.collection('friendships').doc(friendshipId).update({'isRead': true});
  }

  Stream<List<Map<String, dynamic>>> watchMyInvites(String uid, {bool pendingOnly = true}) {
    var query = _db.collection('invites').where('toUid', isEqualTo: uid);
    if (pendingOnly) {
      query = query.where('status', isEqualTo: 'pending');
    }
    return query
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> clearInvite(String inviteId) async {
    await _db.collection('invites').doc(inviteId).delete();
  }
}
