import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class RoundTimerWidget extends StatefulWidget {
  final DateTime roundStartTime;
  final int revealedSeconds;
  final bool isHost;
  final VoidCallback onRevealThree;
  final VoidCallback onRevealFive;
  final VoidCallback onRevealTen;
  final VoidCallback onRoundEnd;

  const RoundTimerWidget({
    super.key,
    required this.roundStartTime,
    required this.revealedSeconds,
    required this.isHost,
    required this.onRevealThree,
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

  // Phase boundaries, in elapsed seconds since round start.
  static const _phase1End = 12; // 2s clip window
  static const _phase2End = 24; // 3s clip window
  static const _phase3End = 40; // 5s clip window
  static const _phase4End = 60; // 10s clip window — round ends after this

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

      if (elapsed >= _phase1End && widget.revealedSeconds < 3) {
        widget.onRevealThree();
      } else if (elapsed >= _phase2End && widget.revealedSeconds < 5) {
        widget.onRevealFive();
      } else if (elapsed >= _phase3End && widget.revealedSeconds < 10) {
        widget.onRevealTen();
      } else if (elapsed >= _phase4End) {
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
    if (_elapsed < _phase4End) return _phase4End - _elapsed;
    return 0;
  }

  // Reflects the actual server-driven reveal state rather than guessing
  // from elapsed time, so the label always matches what's really playing.
  String get _phaseLabel => '${widget.revealedSeconds}s clip';

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
          padding: EdgeInsets.symmetric(horizontal: context.fs(11, max: 16), vertical: context.fs(5, max: 8)),
          decoration: BoxDecoration(
            color: _timerColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _timerColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.timer, size: context.ff(14, max: 18), color: _timerColor),
              SizedBox(width: context.fs(5, max: 8)),
              Text(
                '${_remaining}s',
                style: TextStyle(color: _timerColor, fontWeight: FontWeight.bold, fontSize: context.ff(14, max: 18)),
              ),
              SizedBox(width: context.fs(6, max: 10)),
              Text('($_phaseLabel)', style: TextStyle(color: Colors.white54, fontSize: context.ff(11, max: 13))),
            ],
          ),
        ),
      ],
    );
  }
}