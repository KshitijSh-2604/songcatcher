import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _controller = TextEditingController();
  bool _hasGuessedCorrectly = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyGuessed();
  }

  @override
  void didUpdateWidget(GuessInputWidget old) {
    super.didUpdateWidget(old);
    // Reset when round changes
    if (old.room.currentRound != widget.room.currentRound ||
        old.room.currentSongId != widget.room.currentSongId) {
      setState(() => _hasGuessedCorrectly = false);
      _controller.clear();
      _checkIfAlreadyGuessed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkIfAlreadyGuessed() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(widget.userId)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(
              () => _hasGuessedCorrectly = data['hasGuessedCorrectly'] ?? false);
    }
  }

  Future<void> _submitGuess() async {
    final guess = _controller.text.trim();
    if (guess.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    _controller.clear();

    try {
      final correct = await widget.gameService.submitGuess(
        roomId: widget.roomId,
        userId: widget.userId,
        guess: guess,
      );

      if (correct && mounted) {
        setState(() => _hasGuessedCorrectly = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('🎉 '),
                Text('Correct! Great catch!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasGuessedCorrectly) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.green.withOpacity(0.1),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text(
              'You caught it! Waiting for others...',
              style: TextStyle(
                  color: Colors.greenAccent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_submitting,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitGuess(),
              decoration: InputDecoration(
                hintText: 'Type song or artist name...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
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
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}