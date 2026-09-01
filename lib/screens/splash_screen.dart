import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _progressController.forward();
    _navigate();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    // Wait for the progress bar to finish (3 seconds)
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    context.go(user != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GridBackground()),
          
          // Floating elements (Stars and Notes)
          Positioned(
            top: context.screenHeight * 0.2,
            left: context.screenWidth * 0.2,
            child: _FloatingElement(child: const _StarIcon(Colors.yellow)),
          ),
          Positioned(
            top: context.screenHeight * 0.3,
            right: context.screenWidth * 0.15,
            child: _FloatingElement(child: const Icon(Icons.link, color: Colors.green, size: 40)),
          ),
          Positioned(
            bottom: context.screenHeight * 0.35,
            left: context.screenWidth * 0.1,
            child: _FloatingElement(child: const Icon(Icons.music_note, color: Colors.indigo, size: 30)),
          ),
          Positioned(
            bottom: context.screenHeight * 0.2,
            right: context.screenWidth * 0.2,
            child: _FloatingElement(child: const _StarIcon(Colors.yellow)),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Container
                NeubrutalistContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 24,
                  color: Colors.white,
                  shadowOffset: 6,
                  child: Image.asset(
                    'assets/images/logo1.png', // Assuming the logo is saved here
                    width: 160,
                    height: 160,
                    errorBuilder: (ctx, _, __) => const Icon(Icons.music_note, size: 100, color: Color(0xFF0001BB)),
                  ),
                ).animate().scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut, duration: 1.seconds),
                
                const Gap(32),

                // Styled SongCatcher.io Text
                _StyledTitle(),
                
                const Gap(60),

                // Loading State
                const Text(
                  'TUNING INSTRUMENTS...',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 2,
                    color: Colors.black54,
                  ),
                ),
                const Gap(12),
                
                // Animated Progress Bar
                Container(
                  width: 240,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(3, 3)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _progressAnim,
                        builder: (context, child) {
                          return FractionallySizedBox(
                            widthFactor: _progressAnim.value,
                            child: Container(color: const Color(0xFFFFFF00)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Positioned(
            bottom: 20,
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Made with ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
                Icon(Icons.favorite, size: 12, color: Colors.red.withOpacity(0.5)),
                Text(
                  ' for music',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyledTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shadow/Outline effect
        Text(
          'SongCatcher.io',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = Colors.black,
          ),
        ),
        Text(
          'SongCatcher.io',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0001BB),
          ),
        ),
      ],
    );
  }
}

class _StarIcon extends StatelessWidget {
  final Color color;
  const _StarIcon(this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.star_border, color: color, size: 30);
  }
}

class _FloatingElement extends StatelessWidget {
  final Widget child;
  const _FloatingElement({required this.child});
  @override
  Widget build(BuildContext context) {
    return child.animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -10, end: 10, duration: 2.seconds, curve: Curves.easeInOut)
        .rotate(begin: -0.05, end: 0.05, duration: 3.seconds, curve: Curves.easeInOut);
  }
}
