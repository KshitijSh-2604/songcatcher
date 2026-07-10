import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/room.dart';
import '../../../services/game_service.dart';
import '../../../utils/responsive.dart';

class GuessInputWidget extends StatefulWidget {
  final String roomId;
  final Room room;
  final String userId;
  final String displayName;
  final GameService gameService;

  const GuessInputWidget({
    super.key,
    required this.roomId,
    required this.room,
    required this.userId,
    required this.displayName,
    required this.gameService,
  });

  @override
  State<GuessInputWidget> createState() => _GuessInputWidgetState();
}

class _GuessInputWidgetState extends State<GuessInputWidget> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _guessedCorrectly = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkAlreadyGuessed();
  }

  @override
  void didUpdateWidget(GuessInputWidget old) {
    super.didUpdateWidget(old);
    if (old.room.currentRound != widget.room.currentRound || old.room.currentSong != widget.room.currentSong) {
      setState(() => _guessedCorrectly = false);
      _ctrl.clear();
      _checkAlreadyGuessed();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAlreadyGuessed() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.userId)
        .get();
    if (mounted && doc.exists) {
      setState(() => _guessedCorrectly = doc.data()?['hasGuessedCorrectly'] ?? false);
    }
  }

  Future<void> _submitGuess() async {
    final guess = _ctrl.text.trim();
    // Locked out once already correct this round — this is the lockout
    // bug #9 asked for, enforced both here and (defensively) server-side
    // in GameService.submitGuess.
    if (guess.isEmpty || _submitting || _guessedCorrectly) return;

    setState(() => _submitting = true);
    _ctrl.clear();

    try {
      final correct = await widget.gameService.submitGuess(
        roomId: widget.roomId,
        userId: widget.userId,
        displayName: widget.displayName,
        guess: guess,
      );

      if (correct && mounted) {
        setState(() => _guessedCorrectly = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('🎉 '),
                Text('You caught it!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_guessedCorrectly) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: context.fs(16, max: 24), vertical: context.fs(13, max: 20)),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          border: Border(top: BorderSide(color: Colors.green.withOpacity(0.3))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: context.ff(18, max: 24)),
            SizedBox(width: context.fs(8, max: 12)),
            Text(
              'You caught it! Waiting for others...',
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600, fontSize: context.ff(13, max: 16)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.fs(10, max: 18),
        context.fs(9, max: 14),
        context.fs(10, max: 18),
        context.fs(10, max: 16),
      ),
      decoration: const BoxDecoration(
        color: Color(0x08FFFFFF),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              enabled: !_submitting,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitGuess(),
              style: TextStyle(fontSize: context.ff(14, max: 17)),
              decoration: InputDecoration(
                hintText: 'Song title or artist name...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: EdgeInsets.symmetric(horizontal: context.fs(14, max: 22), vertical: context.fs(10, max: 15)),
              ),
            ),
          ),
          SizedBox(width: context.fs(6, max: 10)),
          FilledButton(
            onPressed: _submitting ? null : _submitGuess,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: const CircleBorder(),
              padding: EdgeInsets.all(context.fs(12, max: 17)),
            ),
            child: _submitting
                ? SizedBox(
              width: context.ff(16, max: 20),
              height: context.ff(16, max: 20),
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : Icon(Icons.send_rounded, size: context.ff(18, max: 23)),
          ),
        ],
      ),
    );
  }
}