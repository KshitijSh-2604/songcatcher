import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

// Pure countdown display — 30 seconds per clip stage.
// game_screen.dart drives all auto-advance logic and passes a new ValueKey
// each time the stage changes, which forces this widget to rebuild from zero.
// onRoundEnd is a safety fallback for non-host clients whose local timer
// fires if the host's Firestore update is delayed.

class RoundTimerWidget extends StatefulWidget {
  final int totalSeconds;       // always 30, one full stage window
  final int revealedSeconds;    // current clip stage in seconds, for label
  final VoidCallback onRoundEnd;

  const RoundTimerWidget({
    super.key,
    required this.totalSeconds,
    required this.revealedSeconds,
    required this.onRoundEnd,
  });

  @override
  State<RoundTimerWidget> createState() => _RoundTimerWidgetState();
}

class _RoundTimerWidgetState extends State<RoundTimerWidget> {
  late Timer _ticker;
  late int _remaining;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 1).clamp(0, widget.totalSeconds));
      if (_remaining == 0 && !_ended) {
        _ended = true;
        widget.onRoundEnd();
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Color get _color {
    if (_remaining > 15) return Colors.green;
    if (_remaining > 8)  return Colors.orange;
    return Colors.red;
  }

  String get _stageLabel => '${widget.revealedSeconds}s clip';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(11, max: 16), vertical: context.fs(5, max: 8)),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: context.ff(14, max: 18), color: _color),
          SizedBox(width: context.fs(5, max: 8)),
          Text(
            '${_remaining}s',
            style: TextStyle(
                color: _color,
                fontWeight: FontWeight.bold,
                fontSize: context.ff(14, max: 18)),
          ),
          SizedBox(width: context.fs(6, max: 10)),
          Text(
            '($_stageLabel)',
            style: TextStyle(
                color: Colors.white54, fontSize: context.ff(11, max: 13)),
          ),
        ],
      ),
    );
  }
}