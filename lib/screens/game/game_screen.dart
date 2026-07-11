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
// TODO: import your chat widget here once you paste it, e.g.:
// import 'widgets/chat_widget.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _audioService = SongAudioService();
  final _gameService  = GameService();

  String? _loadedSongId;
  bool    _navigating  = false;
  bool    _showReveal  = false;
  int     _prevRound   = -1;
  int     _prevRevealedSeconds = -1;

  // Prevent double-fire of the all-guessed trigger within a single round.
  bool _allGuessedTriggered = false;

  Timer? _stageTimer;

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

    final songId        = songData['id']             as String? ?? '';
    final audioUrl      = songData['audioUrl']       as String? ?? '';
    final silenceOffset = (songData['silenceOffset'] as num?)?.toInt() ?? 0;
    if (audioUrl.isEmpty) return;

    if (_loadedSongId != songId) {
      _loadedSongId = songId;
      await _audioService.loadSong(audioUrl, silenceOffset: silenceOffset);
    }
    _audioService.playClip(room.revealedSeconds);
  }

  // ── Stage timer (host only, 30 s per stage) ───────────────────────────────

  void _startStageTimer(int currentStage, bool isHost) {
    _stageTimer?.cancel();
    if (!isHost) return;

    _stageTimer = Timer(const Duration(seconds: 30), () async {
      if (!mounted) return;
      final idx = _stages.indexOf(currentStage);
      if (idx >= 0 && idx < _stages.length - 1) {
        // Not the last stage — advance clip length.
        await _gameService.revealMoreClip(widget.roomId, _stages[idx + 1]);
      } else {
        // Last stage (10 s) expired — end the round.
        _audioService.stopClip();
        _gameService.forceEndRoundIfActive(widget.roomId);
        if (mounted && !_showReveal) setState(() => _showReveal = true);
      }
    });
  }

  Future<void> _onSongLoad(
      String songId, String audioUrl, int silenceOffset) async {
    if (_loadedSongId == songId) return;
    _loadedSongId = songId;
    await _audioService.loadSong(audioUrl, silenceOffset: silenceOffset);
  }

  // ── Trigger reveal safely (deferred to next frame) ───────────────────────
  //
  // Using addPostFrameCallback means any in-progress widget rebuilds (e.g.
  // GuessInputWidget finishing its async _onSubmit) complete first. This
  // prevents the host's guess input from appearing frozen when it is the
  // last player to guess and the all-guessed detection fires mid-await.

  void _triggerReveal() {
    if (_showReveal || _allGuessedTriggered) return;
    _allGuessedTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stageTimer?.cancel();
      _audioService.stopClip();
      _gameService.forceEndRoundIfActive(widget.roomId);
      setState(() => _showReveal = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final user      = ref.watch(currentUserProvider);
    final isHost    = user?.uid != null &&
        roomAsync.valueOrNull?.hostId == user!.uid;

    // ── React to room changes ────────────────────────────────────────────
    ref.listen(roomProvider(widget.roomId), (_, next) {
      final room = next.valueOrNull;
      if (room == null || !mounted) return;

      if (room.currentRound != _prevRound) {
        // New round — reset everything.
        _prevRound            = room.currentRound;
        _prevRevealedSeconds  = room.revealedSeconds;
        _allGuessedTriggered  = false;
        if (_showReveal) setState(() => _showReveal = false);
        _loadAndAutoPlay(room);
        _startStageTimer(room.revealedSeconds, isHost);
        return;
      }

      if (room.revealedSeconds != _prevRevealedSeconds) {
        // Stage advanced — auto-play new clip length, restart timer.
        _prevRevealedSeconds = room.revealedSeconds;
        _audioService.playClip(room.revealedSeconds);
        _startStageTimer(room.revealedSeconds, isHost);
      }
    });

    // ── All players guessed → reveal card ───────────────────────────────
    //
    // Guards:
    //   1. room.status must be RoomStatus.playing (not a leftover state)
    //   2. _prevRound must match room.currentRound (not a stale players snapshot
    //      from the previous round where hasGuessedCorrectly was never reset)
    //   3. _allGuessedTriggered prevents double-fire within the same round
    ref.listen(playersProvider(widget.roomId), (_, next) {
      final players = next.valueOrNull;
      if (players == null || players.isEmpty || !mounted) return;

      // Read current room to validate status and round.
      final room = ref.read(roomProvider(widget.roomId)).valueOrNull;
      if (room == null) return;
      if (room.status != RoomStatus.playing) return;
      if (room.currentRound != _prevRound) return; // stale snapshot
      if (_showReveal || _allGuessedTriggered) return;

      if (players.every((p) => p.hasGuessedCorrectly)) {
        _triggerReveal();
      }
    });

    return roomAsync.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          return const Scaffold(
              body: Center(child: Text('Room not found.')));
        }

        if (room.status == RoomStatus.finished && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${widget.roomId}');
          });
        }

        final roundIsOver = _showReveal ||
            room.status == RoomStatus.roundEnded;
        final displayName = user?.displayName ?? 'Player';

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
                    key: ValueKey(
                        '${room.currentRound}_${room.revealedSeconds}'),
                    totalSeconds: 30,
                    revealedSeconds: room.revealedSeconds,
                    onRoundEnd: () {
                      // Client-side safety fallback for non-host only.
                      // The host's _stageTimer handles the authoritative end.
                      if (!_showReveal && !isHost) {
                        _triggerReveal();
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
                      _allGuessedTriggered = true;
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
                    _allGuessedTriggered = false;
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

// ── Round Indicator ───────────────────────────────────────────────────────────

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

// ── Player Count Badge ────────────────────────────────────────────────────────

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
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Game Body ─────────────────────────────────────────────────────────────────

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
          onReveal: (seconds) =>
              gameService.revealMoreClip(roomId, seconds),
          onEndRound: onEndRound,
        ),
        const Divider(height: 1),
        // ── Guess history / unified chat ─────────────────────────────
        // TODO: if you have a ChatWidget, replace or wrap GuessHistoryWidget:
        //   Expanded(child: ChatWidget(roomId: roomId)),
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