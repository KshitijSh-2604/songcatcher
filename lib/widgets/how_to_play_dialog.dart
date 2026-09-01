import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/responsive.dart';

class HowToPlayDialog extends StatefulWidget {
  const HowToPlayDialog({super.key});

  @override
  State<HowToPlayDialog> createState() => _HowToPlayDialogState();
}

class _HowToPlayDialogState extends State<HowToPlayDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      emoji: '🎧',
      title: 'LISTEN & VIBE',
      desc: 'The round starts with a short clip of a hit song. Pay attention to the beat!',
      color: const Color(0xFFFFFF00),
    ),
    OnboardingStep(
      emoji: '⌨️',
      title: 'QUICK CATCH',
      desc: 'Type the song title as fast as you can. Spelling matters, but we\'re a bit fuzzy!',
      color: const Color(0xFF00FF00),
    ),
    OnboardingStep(
      emoji: '💡',
      title: 'NEED HELP?',
      desc: 'If it\'s too hard, wait! The clip length increases over time to give you more clues.',
      color: const Color(0xFF4D4DFF),
      textColor: Colors.white,
    ),
    OnboardingStep(
      emoji: '🏆',
      title: 'WIN THE ARENA',
      desc: 'The faster you catch it, the more MusCoins you earn. Aim for the top of the leaderboard!',
      color: const Color(0xFF720100),
      textColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _steps.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: NeubrutalistContainer(
        color: Theme.of(context).cardColor,
        padding: EdgeInsets.zero,
        width: context.fw(320, max: 450),
        height: 520,
        child: Column(
          children: [
            // ── Top Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black,
              child: const Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('HOW TO PLAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2)),
                ],
              ),
            ),

            // ── Content PageView ─────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _steps.length,
                itemBuilder: (ctx, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NeubrutalistContainer(
                          color: step.color,
                          borderRadius: 999,
                          padding: const EdgeInsets.all(24),
                          shadowOffset: 6,
                          child: Text(step.emoji, style: const TextStyle(fontSize: 48)),
                        ).animate(key: ValueKey(i)).scale(curve: Curves.elasticOut, duration: 600.ms).rotate(begin: 0.1, end: 0),
                        const SizedBox(height: 32),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.desc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Indicators ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentPage == i ? Theme.of(context).primaryColor : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // ── Footer ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: NeubrutalistButton(
                label: 'GOT IT, LET\'S GO!',
                color: const Color(0xFF00FF00),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String emoji;
  final String title;
  final String desc;
  final Color color;
  final Color? textColor;

  OnboardingStep({required this.emoji, required this.title, required this.desc, required this.color, this.textColor});
}
