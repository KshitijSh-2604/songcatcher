import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_user.dart';
import '../models/daily_challenge.dart';
import '../services/user_service.dart';
import '../services/daily_challenge_service.dart';
import 'auth_provider.dart';

final userServiceProvider = Provider((ref) => UserService());
final dailyChallengeServiceProvider = Provider((ref) => DailyChallengeService());

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
        email: user.email,
        phoneNumber: user.phoneNumber,
        isEmailVerified: user.emailVerified,
        isPhoneVerified: user.phoneNumber != null,
        createdAt: DateTime.now(),
        avatarConfig: AvatarConfig.random().toMap(),
      );
      await service.createUser(newProfile);
      return newProfile;
    }
    
    // Sync verification status from Firebase Auth
    // We only update if Firebase says it's verified but Firestore doesn't.
    // We don't "downgrade" if Firebase is stale.
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
