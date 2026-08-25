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
  bool _skipped = false;

  Timer? _stageTimer;

  @override
  void initState() {
    super.initState();
    // Record current room ID for sidebar persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentRoomIdProvider.notifier).state = widget.roomId;
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── Stage timer (host only) ───────────────────────────────

  void _startStageTimer(Room room, bool isHost, {int delaySeconds = 0}) {
    _stageTimer?.cancel();
    if (!isHost) return;

    final currentStage = room.revealedSeconds;
    final stages = room.selectedClipStages;
    final duration = GameService.getRoundDurationForStage(currentStage);

    _stageTimer = Timer(Duration(seconds: duration + delaySeconds), () async {
      if (!mounted) return;
      final idx = stages.indexOf(currentStage);
      if (idx >= 0 && idx < stages.length - 1) {
        // Not the last stage — advance clip length.
        await _gameService.revealMoreClip(widget.roomId, stages[idx + 1]);
      } else {
        // Last stage expired — end the round.
        _audioService.stopClip();
        await _gameService.forceEndRoundIfActive(widget.roomId);
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

      // Host Handover Logic
      final players = ref.read(playersProvider(widget.roomId)).valueOrNull ?? [];
      final hostExists = players.any((p) => p.id == room.hostId);
      if (!hostExists && players.isNotEmpty && user?.uid == players.first.id) {
        _gameService.handleHostHandover(widget.roomId);
      }

      if (room.currentRound != _prevRound) {
        // New round — reset everything.
        _prevRound            = room.currentRound;
        _prevRevealedSeconds  = room.revealedSeconds;
        _allGuessedTriggered  = false;
        _skipped              = false;
        if (_showReveal) setState(() => _showReveal = false);
        // We'll let ClipPlayerWidget handle the visual countdown 
        // and then it will call onSongLoad (which is fine).
        // But for AutoPlay, we should delay it if we want a countdown.
        _startStageTimer(room, isHost, delaySeconds: 3); // Add 3s delay to account for countdown
        return;
      }

      if (room.revealedSeconds != _prevRevealedSeconds) {
        // Stage advanced — restart timer.
        _prevRevealedSeconds = room.revealedSeconds;
        _startStageTimer(room, isHost, delaySeconds: 3); // Add 3s delay
      }

      // Check for Skip Votes
      if (players.isNotEmpty && room.status == RoomStatus.playing && !_skipped) {
        if (room.skipVotes.length >= (players.length / 2).ceil()) {
          _skipped = true;
          _gameService.skipRound(widget.roomId);
        }
      }
    });

    // ── All players guessed → reveal card ───────────────────────────────
    ref.listen(playersProvider(widget.roomId), (_, next) {
      final players = next.valueOrNull;
      if (players == null || players.isEmpty || !mounted) return;

      final room = ref.read(roomProvider(widget.roomId)).valueOrNull;
      if (room == null) return;
      if (room.status != RoomStatus.playing) return;
      if (room.currentRound != _prevRound) return; 
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

        return PageShell(
          showHeader: true,
          showSidebar: false, 
          padding: EdgeInsets.zero,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Leave Match?'),
                  content: const Text('Are you sure you want to quit this live match? You will lose your current progress.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true), 
                      child: const Text('LEAVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (shouldLeave == true && mounted) {
                ref.read(currentRoomIdProvider.notifier).state = null;
                context.go('/home');
              }
            },
            child: SizedBox(
              height: context.screenHeight - 70, 
              child: Column(
                children: [
                  if (context.isMobile)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          NeubrutalistButton(
                            label: '← QUIT',
                            color: Colors.white,
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Left: Leaderboard ─────────────────────────────────
                        if (!context.isMobile)
                          Container(
                            width: context.fw(240, max: 300),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(right: BorderSide(color: Colors.black, width: 3)),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: NeubrutalistButton(
                                    label: '← QUIT MATCH',
                                    color: Colors.white,
                                    onPressed: () => Navigator.maybePop(context),
                                  ),
                                ),
                                Expanded(child: ScoreboardWidget(roomId: widget.roomId)),
                              ],
                            ),
                          ),

                        // ── Center: Game Canvas ────────────────────────────────
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              _GameBody(
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
                              ),
                              if (roundIsOver && room.currentSong != null)
                                RoundRevealWidget(
                                  roomId: widget.roomId,
                                  song: Song.fromMap(room.currentSong!),
                                  isHost: isHost,
                                  isSkipped: room.isSkipped,
                                  onNextRound: () {
                                    _stageTimer?.cancel();
                                    _allGuessedTriggered = false;
                                    _gameService.endRound(widget.roomId, room);
                                  },
                                ),
                            ],
                          ),
                        ),

                        // ── Right: Live Chat ──────────────────────────────────
                        if (!context.isMobile)
                          Container(
                            width: context.fw(260, max: 340),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(left: BorderSide(color: Colors.black, width: 3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: const Color(0xFF720100), 
                                  child: const Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text(
                                        'Live Chat',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: GuessHistoryWidget(
                                    roomId: widget.roomId,
                                    userId: user.uid,
                                    roundNumber: room.currentRound,
                                  ),
                                ),
                                GuessInputWidget(
                                  roomId: widget.roomId,
                                  room: room,
                                  userId: user.uid,
                                  displayName: displayName,
                                  gameService: _gameService,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
        const Divider(height: 1, color: Color(0xFFD4D9E2)),
        if (context.isMobile) ...[
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
        ] else
          const Spacer(),
      ],
    );
  }
}
