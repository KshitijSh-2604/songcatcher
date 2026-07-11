import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/audio_service.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';
import 'widgets/clip_player_widget.dart';
import 'widgets/guess_input_widget.dart';
import 'widgets/guess_history_widget.dart';
import 'widgets/scoreboard_widget.dart';
import 'widgets/round_reveal_widget.dart';
import 'widgets/round_timer_widget.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _audioService = SongAudioService();
  final _gameService  = GameService();

  // ── State tracking ────────────────────────────────────────────────────────
  String? _loadedSongId;
  bool    _navigating  = false;
  bool    _showReveal  = false;
  int     _prevRound   = -1;
  int     _prevRevealedSeconds = -1;

  // 30-second per-stage auto-advance timer (host only).
  Timer? _stageTimer;

  // Clip reveal stages, mirrored from GameService for local use.
  static const _stages = [2, 3, 5, 10];

  @override
  void dispose() {
    _stageTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── Load + auto-play ──────────────────────────────────────────────────────

  Future<void> _loadAndAutoPlay(Room room) async {
    final songData = room.currentSong;
    if (songData == null) return;

    final songId       = songData['id']            as String? ?? '';
    final audioUrl     = songData['audioUrl']      as String? ?? '';
    final silenceOffset = (songData['silenceOffset'] as num?)?.toInt() ?? 0;
    if (audioUrl.isEmpty) return;

    if (_loadedSongId != songId) {
      _loadedSongId = songId;
      await _audioService.loadSong(audioUrl, silenceOffset: silenceOffset);
    }
    // Always play the currently revealed clip length.
    _audioService.playClip(room.revealedSeconds);
  }

  // ── Stage timer (host only, 30 s per stage) ───────────────────────────────
  //
  // Called whenever the active stage changes. After 30 s the host client
  // advances to the next stage automatically; if already at the last stage
  // (10 s clip) it ends the round.

  void _startStageTimer(int currentStage, bool isHost) {
    _stageTimer?.cancel();
    if (!isHost) return;

    _stageTimer = Timer(const Duration(seconds: 30), () async {
      if (!mounted) return;
      final idx = _stages.indexOf(currentStage);
      if (idx >= 0 && idx < _stages.length - 1) {
        // Advance to next stage — room update will trigger auto-play + new timer.
        await _gameService.revealMoreClip(widget.roomId, _stages[idx + 1]);
      } else {
        // Last stage (10 s) expired — end the round.
        _audioService.stopClip();
        _gameService.forceEndRoundIfActive(widget.roomId);
        if (mounted && !_showReveal) setState(() => _showReveal = true);
      }
    });
  }

  // ── Called when the song is loaded from ClipPlayerWidget ──────────────────
  //
  // Kept as a callback for ClipPlayerWidget backwards-compat; actual play
  // is now driven by ref.listen detecting room changes.

  Future<void> _onSongLoad(String songId, String audioUrl, int silenceOffset) async {
    if (_loadedSongId == songId) return;
    _loadedSongId = songId;
    await _audioService.loadSong(audioUrl, silenceOffset: silenceOffset);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync    = ref.watch(roomProvider(widget.roomId));
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user         = ref.watch(currentUserProvider);
    final isHost       = user?.uid != null &&
        roomAsync.valueOrNull?.hostId == user!.uid;

    // ── React to room changes ────────────────────────────────────────────
    ref.listen(roomProvider(widget.roomId), (_, next) {
      final room = next.valueOrNull;
      if (room == null || !mounted) return;

      // New round started (or first round) → reset reveal, auto-play, start timer.
      if (room.currentRound != _prevRound) {
        _prevRound           = room.currentRound;
        _prevRevealedSeconds = room.revealedSeconds;
        if (_showReveal) setState(() => _showReveal = false);
        _loadAndAutoPlay(room);
        _startStageTimer(room.revealedSeconds, isHost);
        return;
      }

      // Stage advanced (host revealed a longer clip) → auto-play + restart timer.
      if (room.revealedSeconds != _prevRevealedSeconds) {
        _prevRevealedSeconds = room.revealedSeconds;
        _audioService.playClip(room.revealedSeconds);
        _startStageTimer(room.revealedSeconds, isHost);
      }
    });

    // ── All players guessed → show reveal card immediately ───────────────
    ref.listen(playersProvider(widget.roomId), (_, next) {
      final players = next.valueOrNull;
      if (players == null || players.isEmpty || !mounted) return;
      if (players.every((p) => p.hasGuessedCorrectly) && !_showReveal) {
        setState(() => _showReveal = true);
        _stageTimer?.cancel();
        _audioService.stopClip();
        _gameService.forceEndRoundIfActive(widget.roomId);
      }
    });

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:   (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          return const Scaffold(body: Center(child: Text('Room not found.')));
        }

        if (room.status == RoomStatus.finished && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${widget.roomId}');
          });
        }

        final roundIsOver  = _showReveal || room.status == RoomStatus.roundEnded;
        final displayName  = user?.displayName ?? 'Player';

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: _RoundIndicator(
                current: room.currentRound, total: room.totalRounds),
            actions: [
              if (!roundIsOver && room.roundStartedAt != null)
                Padding(
                  padding: EdgeInsets.only(right: context.fs(8, max: 14)),
                  child: RoundTimerWidget(
                    // Key on round + stage so widget resets its 30 s countdown
                    // each time a new stage is revealed.
                    key: ValueKey('${room.currentRound}_${room.revealedSeconds}'),
                    totalSeconds: 30,
                    revealedSeconds: room.revealedSeconds,
                    onRoundEnd: () {
                      // Safety: client-side timer fires if host timer fails.
                      if (!_showReveal && !isHost) {
                        setState(() => _showReveal = true);
                      }
                    },
                  ),
                ),
              _PlayerCountBadge(roomId: widget.roomId),
              SizedBox(width: context.fs(6, max: 12)),
            ],
          ),
          body: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;

                  final body = _GameBody(
                    room: room,
                    roomId: widget.roomId,
                    userId: user!.uid,
                    displayName: displayName,
                    isHost: isHost,
                    audioService: _audioService,
                    gameService: _gameService,
                    onSongLoad: _onSongLoad,
                    onEndRound: () {
                      _stageTimer?.cancel();
                      _audioService.stopClip();
                      setState(() => _showReveal = true);
                    },
                  );

                  if (!isWide) return body;

                  final sidebarWidth =
                  (constraints.maxWidth * 0.22).clamp(180.0, 280.0);

                  return Row(
                    children: [
                      Expanded(flex: 3, child: body),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: sidebarWidth,
                        child: ScoreboardWidget(roomId: widget.roomId),
                      ),
                    ],
                  );
                },
              ),
              if (roundIsOver && room.currentSong != null)
                RoundRevealWidget(
                  roomId: widget.roomId,
                  song: Song.fromMap(room.currentSong!),
                  isHost: isHost,
                  onNextRound: () {
                    _stageTimer?.cancel();
                    _gameService.endRound(widget.roomId, room);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Round Indicator ──────────────────────────────────────────────────────────

class _RoundIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _RoundIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🎵 ', style: TextStyle(fontSize: context.ff(14, max: 18))),
        Text('Round $current / $total',
            style: TextStyle(fontSize: context.ff(14, max: 18))),
      ],
    );
  }
}

// ── Player Count Badge ───────────────────────────────────────────────────────

class _PlayerCountBadge extends ConsumerWidget {
  final String roomId;
  const _PlayerCountBadge({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersProvider(roomId));
    return playersAsync.when(
      data: (players) => Chip(
        avatar: Icon(Icons.people, size: context.ff(13, max: 16)),
        label: Text('${players.length}',
            style: TextStyle(fontSize: context.ff(12, max: 14))),
        visualDensity: VisualDensity.compact,
      ),
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Game Body ────────────────────────────────────────────────────────────────

class _GameBody extends StatelessWidget {
  final Room room;
  final String roomId;
  final String userId;
  final String displayName;
  final bool isHost;
  final SongAudioService audioService;
  final GameService gameService;
  final Future<void> Function(String, String, int) onSongLoad;
  final VoidCallback onEndRound;

  const _GameBody({
    required this.room,
    required this.roomId,
    required this.userId,
    required this.displayName,
    required this.isHost,
    required this.audioService,
    required this.gameService,
    required this.onSongLoad,
    required this.onEndRound,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipPlayerWidget(
          room: room,
          audioService: audioService,
          onSongLoad: onSongLoad,
          isHost: isHost,
          onReveal: (seconds) => gameService.revealMoreClip(roomId, seconds),
          onEndRound: onEndRound,
        ),
        const Divider(height: 1),
        Expanded(
          child: GuessHistoryWidget(
            roomId: roomId,
            userId: userId,
            roundNumber: room.currentRound,
          ),
        ),
        GuessInputWidget(
          roomId: roomId,
          room: room,
          userId: userId,
          displayName: displayName,
          gameService: gameService,
        ),
      ],
    );
  }
}