import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/room.dart';
import '../../../services/game_service.dart';

class GuessInputWidget extends StatefulWidget {
  final String roomId;
  final Room room;
  final String userId;
  final GameService gameService;

  const GuessInputWidget({
    super.key,
    required this.roomId,
    required this.room,
    required this.userId,
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
    // Reset on new round
    if (old.room.currentRound != widget.room.currentRound ||
        old.room.currentSongId != widget.room.currentSongId) {
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
      setState(() => _guessedCorrectly =
          doc.data()?['hasGuessedCorrectly'] ?? false);
    }
  }

  Future<void> _submitGuess() async {
    final guess = _ctrl.text.trim();
    if (guess.isEmpty || _submitting || _guessedCorrectly) return;

    setState(() => _submitting = true);
    _ctrl.clear();

    try {
      final correct = await widget.gameService.submitGuess(
        roomId: widget.roomId,
        userId: widget.userId,
        guess: guess,
      );

      if (correct && mounted) {
        setState(() => _guessedCorrectly = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('🎉 '),
                Text(
                  'You caught it!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          border: Border(
              top: BorderSide(
                  color: Colors.green.withOpacity(0.3))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Text(
              'You caught it! Waiting for others...',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: const Border(top: BorderSide(color: Colors.white12)),
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
              decoration: InputDecoration(
                hintText: 'Song title or artist name...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _submitting ? null : _submitGuess,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: _submitting
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}