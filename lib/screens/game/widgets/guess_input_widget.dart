import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/room.dart';
import '../../../providers/room_provider.dart';
import '../../../services/game_service.dart';
import '../../../utils/responsive.dart';

class GuessInputWidget extends ConsumerStatefulWidget {
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
  ConsumerState<GuessInputWidget> createState() => _GuessInputWidgetState();
}

class _GuessInputWidgetState extends ConsumerState<GuessInputWidget> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _guessedCorrectly = false;
  bool _submitting = false;

  // Track which song + round we last initialized for, so didUpdateWidget
  // only resets state when the actual song changes — not on every Firestore
  // snapshot (which produces a new Map object each time, breaking == comparison).
  String? _lastSongId;
  int _lastRound = -1;

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.room.currentSong?['id'] as String?;
    _lastRound  = widget.room.currentRound;
    _checkAlreadyGuessed();
  }

  @override
  void didUpdateWidget(GuessInputWidget old) {
    super.didUpdateWidget(old);

    final newSongId = widget.room.currentSong?['id'] as String?;
    final newRound  = widget.room.currentRound;

    // Only reset when the song or round actually changes, not on every
    // Firestore snapshot (Map reference equality always differs per snapshot).
    if (newRound != _lastRound || newSongId != _lastSongId) {
      _lastRound  = newRound;
      _lastSongId = newSongId;
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
    // Locked out once already correct this round — bug #9 lockout,
    // enforced both here and defensively server-side in GameService.submitGuess.
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

  Future<void> _voteSkip() async {
    if (widget.room.skipVotes.contains(widget.userId)) return;
    await widget.gameService.voteToSkip(widget.roomId, widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final hasVotedSkip = widget.room.skipVotes.contains(widget.userId);

    if (_guessedCorrectly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF00).withOpacity(0.1),
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF026E00)),
            SizedBox(width: 12),
            Text(
              'YOU CAUGHT IT!',
              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF026E00)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: NeubrutalistContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shadowOffset: 0,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : Colors.white,
                  borderWidth: 2,
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitGuess(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'Song title...',
                      hintStyle: TextStyle(color: Theme.of(context).hintColor),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _submitting ? null : _submitGuess,
                child: NeubrutalistContainer(
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).primaryColor,
                  shadowOffset: 2,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Skips: ${widget.room.skipVotes.length} / ${(ref.watch(playersProvider(widget.roomId)).valueOrNull?.length ?? 1 / 2).ceil()}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).hintColor),
                ),
              ),
              GestureDetector(
                onTap: hasVotedSkip ? null : _voteSkip,
                child: NeubrutalistContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: hasVotedSkip ? Theme.of(context).disabledColor : const Color(0xFFFFFF00),
                  shadowOffset: hasVotedSkip ? 0 : 2,
                  borderWidth: 2,
                  child: Text(
                    hasVotedSkip ? 'VOTED SKIP' : 'VOTE SKIP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 10,
                      color: hasVotedSkip ? Theme.of(context).hintColor : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}