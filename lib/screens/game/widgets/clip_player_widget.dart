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

class _ClipPlayerWidgetState extends State<ClipPlayerWidget> with SingleTickerProviderStateMixin {
  Song? _song;
  bool _playing = false;
  bool _loadingAudio = false;
  Timer? _stopTimer;

  late final AnimationController _playCtrl;
  late final Animation<double> _playScale;

  static const _revealTiers = [2, 3, 5, 10];

  @override
  void initState() {
    super.initState();
    _playCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _playScale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _playCtrl, curve: Curves.easeInOut));
    _loadSong();
  }

  @override
  void didUpdateWidget(ClipPlayerWidget old) {
    super.didUpdateWidget(old);
    final oldId = old.room.currentSong?['spotifyId'];
    final newId = widget.room.currentSong?['spotifyId'];
    if (oldId != newId) {
      _stopTimer?.cancel();
      setState(() {
        _song = null;
        _playing = false;
      });
      _loadSong();
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _playCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSong() async {
    final songData = widget.room.currentSong;
    if (songData == null) return;
    setState(() => _loadingAudio = true);
    try {
      final song = Song.fromMap(songData);
      if (!mounted) return;
      setState(() => _song = song);
      await widget.onSongLoad(song.id, song.audioUrl, song.silenceOffset);
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _playClip() async {
    if (_playing || _song == null) return;
    _playCtrl.forward().then((_) => _playCtrl.reverse());
    setState(() => _playing = true);

    final durationSeconds = widget.room.revealedSeconds;
    _stopTimer?.cancel();

    try {
      // Fire-and-forget the actual playback call, but enforce the cutoff
      // here regardless of what playClip() does internally — this is the
      // fix for clips continuing to play past their allotted reveal time.
      final playFuture = widget.audioService.playClip(durationSeconds);

      _stopTimer = Timer(Duration(milliseconds: durationSeconds * 1000 + 150), () {
        widget.audioService.stopClip();
        if (mounted) setState(() => _playing = false);
      });

      await playFuture;
    } finally {
      // If playClip() finished on its own before the hard-stop timer fired,
      // reflect that immediately rather than waiting for the timer.
      if (mounted && _stopTimer?.isActive == true) {
        setState(() => _playing = false);
        _stopTimer?.cancel();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // ── Clip reveal bars ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _revealTiers.map((s) {
              final revealed = widget.room.revealedSeconds >= s;
              final isCurrent = widget.room.revealedSeconds == s;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: EdgeInsets.symmetric(horizontal: context.fs(4, max: 7)),
                width: s * context.fw(8, max: 13),
                height: context.fs(40, max: 60),
                decoration: BoxDecoration(
                  color: revealed ? Colors.purpleAccent : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(context.fs(6, max: 10)),
                  border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
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

          // ── Play button ─────────────────────────────────────────────
          _loadingAudio
              ? const CircularProgressIndicator()
              : ScaleTransition(
            scale: _playScale,
            child: FilledButton.icon(
              onPressed: (_song == null || _playing) ? null : _playClip,
              icon: Icon(
                _playing ? Icons.graphic_eq : Icons.play_arrow_rounded,
                size: context.ff(18, max: 26),
              ),
              label: Text(
                _playing ? 'Playing ${widget.room.revealedSeconds}s...' : 'Play ${widget.room.revealedSeconds}s Clip',
                style: TextStyle(fontSize: context.ff(13, max: 17)),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _playing ? Colors.deepPurple : Colors.purpleAccent,
                padding: EdgeInsets.symmetric(horizontal: context.fs(28, max: 44), vertical: context.fs(12, max: 18)),
              ),
            ),
          ),

          // ── Host controls ───────────────────────────────────────────
          if (widget.isHost) ...[
            Gap(context.fs(12, max: 18)),
            Wrap(
              spacing: context.fs(6, max: 10),
              runSpacing: context.fs(6, max: 10),
              alignment: WrapAlignment.center,
              children: [
                for (final tier in _revealTiers.where((t) => t > 2))
                  if (widget.room.revealedSeconds < tier)
                    OutlinedButton.icon(
                      onPressed: () => widget.onReveal(tier),
                      icon: Icon(Icons.unfold_more, size: context.ff(13, max: 17)),
                      label: Text('Reveal ${tier}s', style: TextStyle(fontSize: context.ff(12, max: 14))),
                    ),
                FilledButton.icon(
                  onPressed: widget.onEndRound,
                  icon: Icon(Icons.skip_next_rounded, size: context.ff(14, max: 18)),
                  label: Text('End Round', style: TextStyle(fontSize: context.ff(12, max: 14))),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}