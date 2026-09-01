import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../models/daily_challenge.dart';
import '../models/friendship.dart';
import '../services/user_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/friend_service.dart';
import '../services/game_service.dart';
import 'auth_provider.dart';

final userServiceProvider = Provider((ref) => UserService());
final dailyChallengeServiceProvider = Provider((ref) => DailyChallengeService());
final friendServiceProvider = Provider((ref) => FriendService());
final gameServiceProvider = Provider((ref) => GameService());

final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  
  final service = ref.watch(userServiceProvider);
  
  return service.watchUser(user.uid).asyncMap((profile) async {
    if (profile == null) {
      // Lazy-create profile if missing from Firestore but user is logged in
      final newProfile = AppUser(
        uid: user.uid,
        displayName: user.displayName ?? 'Player',
        catcherId: 'CATCHER#0000', // Will be replaced by service
        email: user.email,
        phoneNumber: user.phoneNumber,
        isEmailVerified: user.emailVerified,
        isPhoneVerified: user.phoneNumber != null,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
        avatarConfig: AvatarConfig.random().toMap(),
      );
      await service.createUser(newProfile);
      return newProfile;
    }
    
    // Sync verification status from Firebase Auth
    bool needsUpdate = false;
    final updates = <String, dynamic>{};

    if (user.emailVerified && !profile.isEmailVerified) {
      updates['isEmailVerified'] = true;
      needsUpdate = true;
    }
    
    if (user.email != null && profile.email != user.email) {
      updates['email'] = user.email;
      needsUpdate = true;
    }

    if (user.phoneNumber != null && profile.phoneNumber != user.phoneNumber) {
      updates['phoneNumber'] = user.phoneNumber;
      updates['isPhoneVerified'] = true;
      needsUpdate = true;
    }

    // Auto-migrate old users without catcher IDs
    if (profile.catcherId == 'CATCHER#0000') {
      updates['catcherId'] = await service.generateUniqueCatcherId();
      needsUpdate = true;
    }

    if (needsUpdate) {
      await service.updateUser(user.uid, updates);
      return AppUser.fromMap(user.uid, {...profile.toMap(), ...updates});
    }
    
    return profile;
  });
});

final dailyLeaderboardProvider = StreamProvider.family<List<DailyAttempt>, String>((ref, vibe) {
  return ref.watch(dailyChallengeServiceProvider).watchLeaderboard(vibe);
});

final friendshipsProvider = StreamProvider.family<List<Friendship>, String>((ref, uid) {
  return ref.watch(friendServiceProvider).watchFriends(uid);
});

final pendingRequestsProvider = StreamProvider.family<List<Friendship>, String>((ref, uid) {
  return ref.watch(friendServiceProvider).watchPendingRequests(uid);
});

final userStreamProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userServiceProvider).watchUser(uid);
});

final invitesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, uid) {
  return ref.watch(friendServiceProvider).watchMyInvites(uid, pendingOnly: false);
});

final globalNotificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(userServiceProvider).watchGlobalNotifications();
});

final friendProfilesProvider = Provider.family<AsyncValue<List<AppUser>>, String>((ref, uid) {
  final friendshipsAsync = ref.watch(friendshipsProvider(uid));
  
  return friendshipsAsync.when(
    data: (friendships) {
      if (friendships.isEmpty) return const AsyncValue.data([]);
      
      final profileStates = friendships.map((f) {
        return ref.watch(userStreamProvider(f.getOtherId(uid)));
      }).toList();

      if (profileStates.any((s) => s.isLoading)) {
        return const AsyncValue.loading();
      }

      final profiles = profileStates
          .map((s) => s.valueOrNull)
          .whereType<AppUser>()
          .toList();
          
      return AsyncValue.data(profiles);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
