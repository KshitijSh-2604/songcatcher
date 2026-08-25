import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of Firebase auth state changes
final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Convenience provider — current user or null
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});

/// True if a user is signed in (including anonymous)
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// True only if signed in with email or Google (not anonymous)
final isRegisteredUserProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return !user.isAnonymous;
});

/// True if the user is a developer/admin
final isDevProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  // Specific dev email check
  return user.email == 'kshitij466e@gmail.com';
});