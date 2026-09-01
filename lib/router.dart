import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/home/profile_screen.dart';
import 'screens/home/leaderboard_screen.dart';
import 'screens/home/friends_screen.dart';

import 'screens/game/daily_challenge_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',

    // ── Auth redirect guard ──────────────────────────────────────────
    redirect: (context, state) {
      final isLoggedIn = authAsync.valueOrNull != null;
      final isLoading = authAsync.isLoading;
      final path = state.matchedLocation;

      // Wait until auth state is known
      if (isLoading) return '/splash';

      // Always allow splash
      if (path == '/splash') return null;

      // Not logged in → force login
      if (!isLoggedIn && path != '/login') return '/login';

      // Already logged in → skip login screen
      if (isLoggedIn && path == '/login') return '/home';

      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (_, __) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/friends',
        builder: (_, __) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/daily',
        builder: (_, __) => const DailyChallengeScreen(),
      ),
      GoRoute(
        path: '/daily/:vibe',
        builder: (_, state) => DailyChallengeScreen(
          initialVibe: state.pathParameters['vibe'],
        ),
      ),
      GoRoute(
        path: '/lobby/:roomId',
        builder: (_, state) => LobbyScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/game/:roomId',
        builder: (_, state) => GameScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/results/:roomId',
        builder: (_, state) => ResultsScreen(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
    ],

    // ── Error page ───────────────────────────────────────────────────
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎵', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'Unknown error',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});