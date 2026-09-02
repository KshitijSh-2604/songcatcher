import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/room.dart';
import '../../../providers/room_provider.dart';
import '../../../services/game_service.dart';
import '../../../services/scoring_service.dart'; // 🆕 Import enum
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
  bool _showCloseFeedback = false; // 🆕 Track near misses
  
  Timer? _typingTimer;
  bool _isTyping = false;

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
    
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_guessedCorrectly) return;
    
    final text = _ctrl.text.trim();
    final currentlyTyping = text.isNotEmpty;

    if (currentlyTyping != _isTyping) {
      _isTyping = currentlyTyping;
      widget.gameService.updateTypingStatus(widget.roomId, widget.userId, _isTyping);
    }

    // Auto-clear typing status after 3 seconds of inactivity
    _typingTimer?.cancel();
    if (currentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isTyping) {
          _isTyping = false;
          widget.gameService.updateTypingStatus(widget.roomId, widget.userId, false);
        }
      });
    }
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
      _isTyping = false;
      _checkAlreadyGuessed();
      // 🎯 Auto-focus when a new round or song starts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _ctrl.removeListener(_onTextChanged);
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

  Future<void> _submitGuess({String? customText}) async {
    final guess = customText ?? _ctrl.text.trim();
    if (guess.isEmpty || _submitting) return;
    
    setState(() => _submitting = true);
    if (customText == null) _ctrl.clear();

    try {
      // If already guessed, it's just chat
      if (_guessedCorrectly && customText == null) {
        await widget.gameService.sendGuess(
          roomId: widget.roomId,
          userId: widget.userId,
          displayName: widget.displayName,
          guess: guess,
        );
        return;
      }

      final result = await widget.gameService.submitGuess(
        roomId: widget.roomId,
        userId: widget.userId,
        displayName: widget.displayName,
        guess: guess,
      );

      if (result == GuessResult.correct && mounted) {
        setState(() => _guessedCorrectly = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                const Text('🎉 '),
                const Text('You caught it!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (result == GuessResult.close && mounted && customText == null) {
        // 🟠 Near miss feedback
        setState(() => _showCloseFeedback = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showCloseFeedback = false);
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
      if (customText == null) {
        // Use a small delay to ensure the keyboard stays open and focus is regained
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    }
  }

  Future<void> _voteSkip() async {
    if (widget.room.skipVotes.contains(widget.userId)) return;
    await widget.gameService.voteToSkip(widget.roomId, widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 1. Quick Chat Chips ──────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _QuickChatChip(label: 'I know this! 💡', onTap: () => _submitGuess(customText: 'I know this! 💡')),
              _QuickChatChip(label: 'What a bop! 🔥', onTap: () => _submitGuess(customText: 'What a bop! 🔥')),
              _QuickChatChip(label: 'Too hard... 💀', onTap: () => _submitGuess(customText: 'Too hard... 💀')),
              _QuickChatChip(label: 'GG', onTap: () => _submitGuess(customText: 'GG')),
            ],
          ),
        ),

        // ── 2. Near Miss / Correct Feedback ──────────────────────────
        if (_guessedCorrectly)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: const Color(0xFF00FF00).withOpacity(0.9),
            child: const Text(
              'YOU CAUGHT IT! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
            ),
          )
        else if (_showCloseFeedback)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.orange.withOpacity(0.9),
            child: const Text(
              'SO CLOSE! 🤏',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
            ),
          ),

        // ── 3. Input Field ───────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(context.fs(10, max: 16)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: NeubrutalistContainer(
                  padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 16), vertical: context.fs(2, max: 4)),
                  shadowOffset: 0,
                  color: isDark ? Colors.white.withOpacity(0.1) : (_guessedCorrectly ? Colors.green.withOpacity(0.1) : (_showCloseFeedback ? Colors.orange.withOpacity(0.1) : Colors.white)),
                  borderWidth: 2,
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitGuess(),
                    style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: context.ff(13, max: 15)),
                    decoration: InputDecoration(
                      hintText: _guessedCorrectly ? 'Chat with others...' : 'Song title...',
                      hintStyle: TextStyle(color: Theme.of(context).hintColor, fontSize: context.ff(12, max: 14)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.fs(8, max: 12)),
              GestureDetector(
                onTap: _submitting ? null : _submitGuess,
                child: NeubrutalistContainer(
                  padding: EdgeInsets.all(context.fs(10, max: 12)),
                  color: _guessedCorrectly ? Colors.green : Theme.of(context).primaryColor,
                  shadowOffset: 2,
                  child: _submitting
                      ? SizedBox(width: context.fs(18, max: 20), height: context.fs(18, max: 20), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_guessedCorrectly ? Icons.chat : Icons.send, color: Colors.white, size: context.fs(18, max: 20)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickChatChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChatChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: NeubrutalistContainer(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shadowOffset: 0,
          borderWidth: 1.5,
          color: Theme.of(context).cardColor,
          child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
