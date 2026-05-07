import 'dart:async';
import 'package:flutter/material.dart';

class RoundTimerWidget extends StatefulWidget {
  final DateTime roundStartTime;
  final int revealedSeconds;
  final bool isHost;
  final VoidCallback onRevealFive;
  final VoidCallback onRevealTen;
  final VoidCallback onRoundEnd;

  const RoundTimerWidget({
    super.key,
    required this.roundStartTime,
    required this.revealedSeconds,
    required this.isHost,
    required this.onRevealFive,
    required this.onRevealTen,
    required this.onRoundEnd,
  });

  @override
  State<RoundTimerWidget> createState() => _RoundTimerWidgetState();
}

class _RoundTimerWidgetState extends State<RoundTimerWidget> {
  late Timer _timer;
  int _elapsed = 0;
  // Phase durations in seconds: 3s clip → 15s, 5s clip → 15s, 10s clip → 20s
  static const _phase1End = 15;
  static const _phase2End = 30;
  static const _phase3End = 50;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(widget.roundStartTime).inSeconds;
      setState(() => _elapsed = elapsed);

      if (!widget.isHost) return;

      // Auto-reveal at phase boundaries
      if (elapsed >= _phase1End && widget.revealedSeconds < 5) {
        widget.onRevealFive();
      } else if (elapsed >= _phase2End && widget.revealedSeconds < 10) {
        widget.onRevealTen();
      } else if (elapsed >= _phase3End) {
        widget.onRoundEnd();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  int get _remaining {
    if (_elapsed < _phase1End) return _phase1End - _elapsed;
    if (_elapsed < _phase2End) return _phase2End - _elapsed;
    if (_elapsed < _phase3End) return _phase3End - _elapsed;
    return 0;
  }

  String get _phaseLabel {
    if (_elapsed < _phase1End) return '3s clip';
    if (_elapsed < _phase2End) return '5s clip';
    return '10s clip';
  }

  Color get _timerColor {
    if (_remaining > 10) return Colors.green;
    if (_remaining > 5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _timerColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _timerColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, size: 16, color: _timerColor),
              const SizedBox(width: 6),
              Text(
                '${_remaining}s',
                style: TextStyle(
                  color: _timerColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($_phaseLabel)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}