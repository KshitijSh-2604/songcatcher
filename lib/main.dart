import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/theme_provider.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  runApp(
    const ProviderScope(
      child: SongCatcherApp(),
    ),
  );
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