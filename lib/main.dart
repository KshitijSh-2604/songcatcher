import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // 🆕 For cleaner URLs
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';

import 'providers/room_provider.dart';
import 'providers/auth_provider.dart';
import 'services/game_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀 OPTIMIZATION: Remove # from URL
  usePathUrlStrategy();

  // Firebase init
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase Init Error: $e');
  }

  // 🛡️ GLOBAL ERROR CATCHING (Production Ready)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Asynchronous Error: $error');
    return true;
  };

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const LifecycleWrapper(child: SongCatcherApp()),
    ),
  );
}

class LifecycleWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const LifecycleWrapper({super.key, required this.child});

  @override
  ConsumerState<LifecycleWrapper> createState() => _LifecycleWrapperState();
}

class _LifecycleWrapperState extends ConsumerState<LifecycleWrapper> {
  late final AppLifecycleListener _listener;
  final _gameService = GameService();
  final _userService = UserService();
  Timer? _backgroundTimer; // ⏲️ Background timeout timer

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onDetach: _handleCleanup,
      onHide: _handleHide,
      onShow: _handleShow,
      onPause: _handleHide,
      onResume: _handleShow,
    );
    // Initial online status
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleShow());
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _listener.dispose();
    super.dispose();
  }

  void _handleShow() {
    _backgroundTimer?.cancel(); // Cancel cleanup if returned early
    final user = ref.read(currentUserProvider);
    if (user != null) _userService.updateOnlineStatus(user.uid, true);
  }

  void _handleHide() {
    final user = ref.read(currentUserProvider);
    if (user != null) _userService.updateOnlineStatus(user.uid, false);

    // ⏲️ Start 2-minute countdown for room cleanup
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer(const Duration(minutes: 2), () {
      final roomId = ref.read(currentRoomIdProvider);
      final user = ref.read(currentUserProvider);
      if (roomId != null && user != null) {
        _gameService.leaveRoom(roomId, user.uid);
        ref.read(currentRoomIdProvider.notifier).state = null;
      }
    });
  }

  void _handleCleanup() {
    final roomId = ref.read(currentRoomIdProvider);
    final user = ref.read(currentUserProvider);
    
    if (user != null) {
      _userService.updateOnlineStatus(user.uid, false);
    }

    if (roomId != null && user != null) {
      _gameService.leaveRoom(roomId, user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class SongCatcherApp extends ConsumerWidget {
  const SongCatcherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SongCatcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.skribbl(),
      darkTheme: AppTheme.skribblDark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}