import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slideAnim = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _navigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    context.go(user != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = context.fs(84, max: 130);

    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo emoji with glow
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.purpleAccent.withOpacity(0.15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withOpacity(0.3),
                            blurRadius: context.fs(32, max: 50),
                            spreadRadius: context.fs(8, max: 13),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text('🎵', style: TextStyle(fontSize: context.ff(42, max: 64))),
                      ),
                    ),
                    Gap(context.fs(20, max: 30)),

                    // App name
                    Text(
                      'SongCatcher',
                      style: TextStyle(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        fontSize: context.ff(30, max: 46),
                      ),
                    ),
                    Gap(context.fs(5, max: 8)),

                    // Tagline
                    Text(
                      'Catch the song before anyone else!',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: context.ff(12, max: 15),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Gap(context.fs(5, max: 8)),

                    // Domain
                    Text(
                      'songcatcher.io',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: context.ff(10, max: 12),
                        letterSpacing: 2,
                      ),
                    ),
                    Gap(context.fs(52, max: 76)),

                    // Loading indicator
                    SizedBox(
                      width: context.ff(20, max: 26),
                      height: context.ff(20, max: 26),
                      child: const CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}