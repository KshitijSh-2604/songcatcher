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
import 'screens/admin/seed_screen.dart';

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
      GoRoute(
        path: '/admin/seed',
        builder: (_, __) => const SeedScreen(),
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
              style: const TextStyle(color: Colors.white54),
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