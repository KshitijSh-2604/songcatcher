import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/room.dart';
import '../../../models/song.dart';
import '../../../services/audio_service.dart';
import '../../../utils/responsive.dart';

class ClipPlayerWidget extends StatefulWidget {
  final Room room;
  final SongAudioService audioService;
  final Future<void> Function(String, String, int) onSongLoad;
  final bool isHost;
  final Future<void> Function(int seconds) onReveal;
  final VoidCallback onEndRound;

  const ClipPlayerWidget({
    super.key,
    required this.room,
    required this.audioService,
    required this.onSongLoad,
    required this.isHost,
    required this.onReveal,
    required this.onEndRound,
  });

  @override
  State<ClipPlayerWidget> createState() => _ClipPlayerWidgetState();
}

class _ClipPlayerWidgetState extends State<ClipPlayerWidget>
    with SingleTickerProviderStateMixin {
  Song?  _song;
  bool   _playing      = false;
  bool   _loadingAudio = false;
  Timer? _stopTimer;

  // One manual replay allowed per clip stage per round.
  // Resets when revealed seconds change (new stage) or new round.
  bool _replayUsed          = false;
  int  _lastRevealedSeconds = -1;

  late final AnimationController _playCtrl;
  late final Animation<double>   _playScale;

  static const _revealTiers = [2, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _playCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _playScale = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _playCtrl, curve: Curves.easeInOut));
    _lastRevealedSeconds = widget.room.revealedSeconds;
    _loadSong(autoPlay: true);
  }

  @override
  void didUpdateWidget(ClipPlayerWidget old) {
    super.didUpdateWidget(old);

    final oldId = old.room.currentSong?['id']    as String?;
    final newId = widget.room.currentSong?['id'] as String?;

    if (oldId != newId) {
      // New song (new round) — full reset.
      _stopTimer?.cancel();
      widget.audioService.stopClip();
      setState(() {
        _song              = null;
        _playing           = false;
        _replayUsed        = false;
        _lastRevealedSeconds = widget.room.revealedSeconds;
      });
      _loadSong(autoPlay: true);
    } else if (widget.room.revealedSeconds != _lastRevealedSeconds) {
      // New clip stage revealed — reset replay allowance for this stage.
      // Auto-play is handled by game_screen's ref.listen; we just reset state.
      setState(() {
        _replayUsed          = false;
        _lastRevealedSeconds = widget.room.revealedSeconds;
        _playing             = false;
      });
      _stopTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _playCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSong({bool autoPlay = false}) async {
    final songData = widget.room.currentSong;
    if (songData == null) return;
    setState(() => _loadingAudio = true);
    try {
      final song = Song.fromMap(songData);
      if (!mounted) return;
      setState(() => _song = song);
      await widget.onSongLoad(song.id, song.audioUrl, song.silenceOffset);
      if (autoPlay && mounted) await _playClip(isAutoPlay: true);
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _playClip({bool isAutoPlay = false}) async {
    if (_song == null) return;

    // Manual replay: only allowed once per clip stage.
    if (!isAutoPlay) {
      if (_replayUsed) return;
      setState(() => _replayUsed = true);
    }

    // If already playing, stop and restart.
    if (_playing) {
      _stopTimer?.cancel();
      widget.audioService.stopClip();
      setState(() => _playing = false);
      await Future.delayed(const Duration(milliseconds: 80));
    }

    _playCtrl.forward().then((_) => _playCtrl.reverse());
    setState(() => _playing = true);

    final durationSeconds = widget.room.revealedSeconds;
    _stopTimer?.cancel();

    try {
      final playFuture = widget.audioService.playClip(durationSeconds);

      // Hard-stop: clip must not play past its allotted time (bug #8).
      _stopTimer = Timer(
        Duration(milliseconds: durationSeconds * 1000 + 150),
            () {
          widget.audioService.stopClip();
          if (mounted) setState(() => _playing = false);
        },
      );

      await playFuture;
    } finally {
      if (mounted && (_stopTimer?.isActive ?? false)) {
        setState(() => _playing = false);
        _stopTimer?.cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReplay = !_replayUsed && !_playing && _song != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.fs(16, max: 28),
        context.fs(16, max: 28),
        context.fs(16, max: 28),
        context.fs(12, max: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Clip stage bars ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _revealTiers.map((s) {
              final revealed  = widget.room.revealedSeconds >= s;
              final isCurrent = widget.room.revealedSeconds == s;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: EdgeInsets.symmetric(horizontal: context.fs(4, max: 7)),
                width:  s * context.fw(8, max: 13),
                height: context.fs(40, max: 60),
                decoration: BoxDecoration(
                  color: revealed
                      ? Colors.purpleAccent
                      : Colors.grey.shade800,
                  borderRadius:
                  BorderRadius.circular(context.fs(6, max: 10)),
                  border: isCurrent
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: revealed
                      ? [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.4),
                      blurRadius: context.fs(10, max: 16),
                      spreadRadius: 2,
                    )
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${s}s',
                    style: TextStyle(
                      color: revealed ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: context.ff(11, max: 15),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Gap(context.fs(14, max: 22)),

          // ── Replay button (1 per clip stage) ─────────────────────────
          _loadingAudio
              ? const CircularProgressIndicator()
              : ScaleTransition(
            scale: _playScale,
            child: Column(
              children: [
                FilledButton.icon(
                  onPressed: canReplay ? () => _playClip() : null,
                  icon: Icon(
                    _playing
                        ? Icons.graphic_eq
                        : Icons.replay_rounded,
                    size: context.ff(18, max: 26),
                  ),
                  label: Text(
                    _playing
                        ? 'Playing ${widget.room.revealedSeconds}s...'
                        : _replayUsed
                        ? 'Replay used'
                        : 'Replay ${widget.room.revealedSeconds}s Clip',
                    style: TextStyle(fontSize: context.ff(13, max: 17)),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _playing
                        ? Colors.deepPurple
                        : canReplay
                        ? Colors.purpleAccent
                        : Colors.grey.shade700,
                    padding: EdgeInsets.symmetric(
                        horizontal: context.fs(28, max: 44),
                        vertical: context.fs(12, max: 18)),
                  ),
                ),
                if (!_playing) ...[
                  Gap(context.fs(4, max: 6)),
                  Text(
                    _replayUsed
                        ? 'No more replays for this clip'
                        : '1 replay remaining',
                    style: TextStyle(
                        color: _replayUsed
                            ? Colors.white24
                            : Colors.white38,
                        fontSize: context.ff(10, max: 12)),
                  ),
                ],
              ],
            ),
          ),

          // ── Host: End Round only (manual reveal removed) ─────────────
          // Stage auto-advances every 30s via game_screen's _stageTimer.
          // Manual clip-length reveal buttons have been removed per design.
          if (widget.isHost) ...[
            Gap(context.fs(12, max: 18)),
            OutlinedButton.icon(
              onPressed: widget.onEndRound,
              icon: Icon(Icons.skip_next_rounded,
                  size: context.ff(14, max: 18),
                  color: Colors.red.shade300),
              label: Text('End Round',
                  style: TextStyle(
                      fontSize: context.ff(12, max: 14),
                      color: Colors.red.shade300)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade700),
                padding: EdgeInsets.symmetric(
                    horizontal: context.fs(16, max: 24),
                    vertical: context.fs(8, max: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}