import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/room.dart';
import '../../../models/song.dart';
import '../../../services/audio_service.dart';
import '../../../services/game_service.dart';
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

  bool _replayUsed          = false;
  int  _lastRevealedSeconds = -1;

  late Timer _countdownTicker;
  int _remainingSeconds = 30;

  // ── Arena Countdown State ──────────────────────────────────────
  int _internalCountdown = 0;
  bool _isTransitioning = false;
  String _transitionMsg = '';

  @override
  void initState() {
    super.initState();
    _lastRevealedSeconds = widget.room.revealedSeconds;
    _remainingSeconds = GameService.getRoundDurationForStage(_lastRevealedSeconds);
    
    // Initial round/clip transition
    _triggerArenaCountdown(isNewRound: true);
    _startCountdown();
  }

  Future<void> _triggerArenaCountdown({required bool isNewRound}) async {
    if (!mounted) return;
    setState(() {
      _isTransitioning = true;
      _transitionMsg = isNewRound ? 'Get ready for Round ${widget.room.currentRound}...' : 'Playing ${widget.room.revealedSeconds}s clip in...';
      _internalCountdown = 3;
    });

    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _internalCountdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() => _isTransitioning = false);
      _loadSong(autoPlay: true);
    }
  }

  void _startCountdown() {
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      // Don't tick down while in a transition countdown
      if (_isTransitioning) return;

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
      });
    });
  }

  @override
  void didUpdateWidget(ClipPlayerWidget old) {
    super.didUpdateWidget(old);
    
    final roundChanged = old.room.currentRound != widget.room.currentRound;
    final stageChanged = old.room.revealedSeconds != widget.room.revealedSeconds;

    if (roundChanged || stageChanged) {
      setState(() {
        _lastRevealedSeconds = widget.room.revealedSeconds;
        _remainingSeconds = GameService.getRoundDurationForStage(_lastRevealedSeconds);
        _replayUsed = false;
      });
      _triggerArenaCountdown(isNewRound: roundChanged);
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _countdownTicker.cancel();
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
    if (!isAutoPlay) {
      if (_replayUsed) return;
      setState(() => _replayUsed = true);
    }
    if (_playing) {
      _stopTimer?.cancel();
      widget.audioService.stopClip();
      setState(() => _playing = false);
      await Future.delayed(const Duration(milliseconds: 80));
    }
    setState(() => _playing = true);
    final durationSeconds = widget.room.revealedSeconds;
    _stopTimer?.cancel();
    try {
      final playFuture = widget.audioService.playClip(durationSeconds);
      _stopTimer = Timer(Duration(milliseconds: durationSeconds * 1000 + 150), () {
        widget.audioService.stopClip();
        if (mounted) setState(() => _playing = false);
      });
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Time Remaining Header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: NeubrutalistContainer(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Time Remaining', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      '00:${_remainingSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF720100)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 24,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.1) : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_remainingSeconds / GameService.getRoundDurationForStage(_lastRevealedSeconds)).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFF00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Main Game Canvas ──────────────────────────────────────────
        SizedBox(
          height: 300, // Bound the height
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NeubrutalistContainer(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
              borderWidth: 4,
              child: Stack(
                children: [
                  Positioned.fill(child: const GridBackground()),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Music Bars
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _MusicBar(height: 60, color: Theme.of(context).dividerColor, delay: 0, playing: _playing),
                            _MusicBar(height: 80, color: const Color(0xFF00FF00), delay: 1, playing: _playing),
                            _MusicBar(height: 100, color: const Color(0xFF00FF00), delay: 2, playing: _playing),
                            _MusicBar(height: 120, color: const Color(0xFF00FF00), delay: 3, playing: _playing),
                            _MusicBar(height: 90, color: const Color(0xFFFFFF00), delay: 4, playing: _playing),
                            _MusicBar(height: 70, color: Theme.of(context).dividerColor, delay: 5, playing: _playing),
                            _MusicBar(height: 110, color: const Color(0xFF4D4DFF), delay: 6, playing: _playing),
                          ],
                        ),
                        const SizedBox(height: 32),
                        if (_isTransitioning)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _transitionMsg,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_internalCountdown',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 48, 
                                  color: Theme.of(context).primaryColor
                                ),
                              ).animate(key: ValueKey(_internalCountdown))
                               .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
                            ],
                          )
                        else
                          NeubrutalistContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Text(
                              'GUESS THE TRACK!',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Theme.of(context).textTheme.bodyLarge?.color),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Replay Button Overlay
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Opacity(
                      opacity: (_replayUsed || _isTransitioning) ? 0.5 : 1.0,
                      child: IconButton.filled(
                        onPressed: _replayUsed || _playing || _isTransitioning ? null : () => _playClip(),
                        icon: const Icon(Icons.replay),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFF00),
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Theme.of(context).dividerColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MusicBar extends StatefulWidget {
  final double height;
  final Color color;
  final int delay;
  final bool playing;

  const _MusicBar({required this.height, required this.color, required this.delay, required this.playing});

  @override
  State<_MusicBar> createState() => _MusicBarState();
}

class _MusicBarState extends State<_MusicBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: 400 + (widget.delay * 50)));
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.playing) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MusicBar old) {
    super.didUpdateWidget(old);
    if (widget.playing) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.animateTo(0.3);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          width: 12,
          height: widget.height * _anim.value,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
          ),
        );
      },
    );
  }
}
