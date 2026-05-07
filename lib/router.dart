import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/results/results_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authAsync.valueOrNull != null;
      final path = state.matchedLocation;

      // Always allow splash
      if (path == '/splash') return null;

      // Not logged in → send to login (except if already there)
      if (!isLoggedIn && path != '/login') return '/login';

      // Already logged in → don't show login
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
        builder: (_, state) =>
            LobbyScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/game/:roomId',
        builder: (_, state) =>
            GameScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/results/:roomId',
        builder: (_, state) =>
            ResultsScreen(roomId: state.pathParameters['roomId']!),
      ),
    ],
  );
});