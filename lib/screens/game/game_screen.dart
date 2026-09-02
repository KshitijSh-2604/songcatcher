import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/user_provider.dart'; // 🆕 Added
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
  
  // ⏸️ Tracking for consistent pause/resume
  DateTime? _stageTimerStartedAt;
  int       _stageTimerDurationSeconds = 0;

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
      
      // 🚀 Update activity status
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(userServiceProvider).updateActivity(user.uid, 'Playing');
      }
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ── Stage timer (host only) ───────────────────────────────

  void _startStageTimer(Room room, bool isHost, {int? durationSeconds, int delaySeconds = 0}) {
    _stageTimer?.cancel();
    if (!isHost || room.isPaused) return;

    final currentStage = room.revealedSeconds;
    final stages = room.selectedClipStages;
    
    // Use provided duration (for resume) or get standard for stage
    final duration = durationSeconds ?? GameService.getRoundDurationForStage(currentStage);
    
    _stageTimerDurationSeconds = duration;
    _stageTimerStartedAt = DateTime.now().add(Duration(seconds: delaySeconds));

    _stageTimer = Timer(Duration(seconds: duration + delaySeconds), () async {
      if (!mounted) return;
      
      _stageTimerStartedAt = null; // Clear tracking

      final idx = stages.indexOf(currentStage);
      if (idx >= 0 && idx < stages.length - 1) {
        // Not the last stage — advance clip length.
        await _gameService.revealMoreClip(widget.roomId, stages[idx + 1]);
      } else {
        // Last stage expired — end the round.
        _audioService.stopClip();
        await _gameService.forceEndRoundIfActive(widget.roomId);
        if (mounted && !_showReveal) {
          setState(() => _showReveal = true);
          // 🔊 Play reveal audio (15s at 75% volume)
          _audioService.setVolume(0.75);
          _audioService.playFullAtVolume(0.75);
        }
      }
    });
  }

  Future<void> _onSongLoad(
      String songId, String audioUrl, int silenceOffset) async {
    final room = ref.read(roomProvider(widget.roomId)).valueOrNull;
    if (room != null && room.isPartyMode) {
      final isHost = ref.read(currentUserProvider)?.uid == room.hostId;
      if (!isHost) {
        debugPrint('Party Mode: Non-host device, skipping audio load.');
        return;
      }
    }

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
      // 🔊 Play reveal audio
      _audioService.setVolume(0.75);
      _audioService.playFullAtVolume(0.75);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final playersAsync = ref.watch(playersProvider(widget.roomId)); // 🆕 Added
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
        _startStageTimer(room, isHost, delaySeconds: 3);
        return;
      }

      if (room.revealedSeconds != _prevRevealedSeconds) {
        _prevRevealedSeconds = room.revealedSeconds;
        _startStageTimer(room, isHost, delaySeconds: 3);
      }

      final pauseChanged = room.isPaused != roomAsync.valueOrNull?.isPaused;
      if (room.isPaused) {
        // ⏸️ Capture elapsed time before cancelling
        if (_stageTimerStartedAt != null) {
          final elapsed = DateTime.now().difference(_stageTimerStartedAt!).inSeconds;
          _stageTimerDurationSeconds = (_stageTimerDurationSeconds - elapsed).clamp(0, 30);
        }
        _stageTimer?.cancel();
        _audioService.pause();
      } else if (pauseChanged && !room.isPaused) {
        // 🔄 Resume with REMAINING time
        _startStageTimer(room, isHost, durationSeconds: _stageTimerDurationSeconds);
      }

      if (players.isNotEmpty && room.status == RoomStatus.playing && !_skipped) {
        if (room.skipVotes.length > (players.length / 2)) {
          _skipped = true;
          // 👑 Only the host has permission to update the room status
          if (isHost) {
            _gameService.skipRound(widget.roomId);
          }
        }
      }
    });

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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) return const Scaffold(body: Center(child: Text('Room not found.')));

        if (room.status == RoomStatus.finished && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/results/${widget.roomId}'));
        }

        final players = playersAsync.valueOrNull ?? [];
        final totalPlayers = players.length;
        final correctCount = players.where((p) => p.hasGuessedCorrectly).length;
        
        final roundIsOver = _showReveal || room.status == RoomStatus.roundEnded;
        final displayName = user?.displayName ?? 'Player';

        return PageShell(
          showHeader: true,
          showSidebar: false, 
          scrollable: false, // 🚫 DISABLE GLOBAL SCROLL
          padding: EdgeInsets.zero,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final shouldLeave = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Leave Match?'),
                  content: const Text('Are you sure you want to quit? You will lose progress.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LEAVE')),
                  ],
                ),
              );
              if (shouldLeave == true && mounted) {
                ref.read(currentRoomIdProvider.notifier).state = null;
                if (user != null) await _gameService.leaveRoom(widget.roomId, user.uid);
                if (mounted) context.go('/home');
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                final isWide = constraints.maxWidth >= 1000;

                return Column(
                  children: [
                    // 🕹️ Header Controls (Small height)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(
                        children: [
                          NeubrutalistButton(
                            label: '← QUIT',
                            color: Colors.white,
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          const Spacer(),
                          if (isHost && (roundIsOver || room.isPaused)) ...[
                            _PauseButton(
                              isPaused: room.isPaused,
                              onToggle: () => _gameService.togglePause(widget.roomId, !room.isPaused),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (!isWide) ...[
                            _ScoreboardButton(roomId: widget.roomId),
                            const SizedBox(width: 8),
                          ],
                          _SkipVoteButton(
                            roomId: widget.roomId,
                            userId: user!.uid,
                            gameService: _gameService,
                            room: room,
                            totalPlayers: totalPlayers,
                          ),
                        ],
                      ),
                    ),

                    // ── Main Content Area ──────────────────────────────────────────
                    Expanded(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left: Scoreboard
                                Container(
                                  width: 280,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
                                  ),
                                  child: ScoreboardWidget(roomId: widget.roomId),
                                ),

                                // Center: Game Canvas
                                Expanded(
                                  child: Stack(
                                    children: [
                                      _GameBody(
                                        room: room, roomId: widget.roomId, userId: user.uid, displayName: displayName,
                                        isHost: isHost, audioService: _audioService, gameService: _gameService,
                                        onSongLoad: _onSongLoad,
                                        totalPlayers: totalPlayers,
                                        correctCount: correctCount,
                                        onEndRound: () {
                                          _stageTimer?.cancel(); _audioService.stopClip(); _allGuessedTriggered = true;
                                          setState(() => _showReveal = true);
                                          _audioService.setVolume(0.75); _audioService.playFullAtVolume(0.75);
                                        },
                                      ),
                                      if (roundIsOver && room.currentSong != null)
                                        RoundRevealWidget(
                                          roomId: widget.roomId, song: Song.fromMap(room.currentSong!),
                                          isHost: isHost, isSkipped: room.isSkipped,
                                          onNextRound: () {
                                            _stageTimer?.cancel(); _audioService.stopClip(); _audioService.setVolume(1.0);
                                            _allGuessedTriggered = false; 
                                            if (isHost) _gameService.endRound(widget.roomId, room);
                                          },
                                        ),
                                    ],
                                  ),
                                ),

                                // Right: Chat
                                Container(
                                  width: 320,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    border: Border(left: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        color: const Color(0xFF720100), 
                                        child: const Row(children: [Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18), SizedBox(width: 12), Text('Live Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))]),
                                      ),
                                      Expanded(child: GuessHistoryWidget(roomId: widget.roomId, userId: user.uid, roundNumber: room.currentRound)),
                                      GuessInputWidget(roomId: widget.roomId, room: room, userId: user.uid, displayName: displayName, gameService: _gameService),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                // 1. Game Canvas (Fixed Aspect/Size)
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: height * 0.5),
                                  child: Stack(
                                    children: [
                                      _GameBody(
                                        room: room, roomId: widget.roomId, userId: user.uid, displayName: displayName,
                                        isHost: isHost, audioService: _audioService, gameService: _gameService,
                                        onSongLoad: _onSongLoad,
                                        totalPlayers: totalPlayers,
                                        correctCount: correctCount,
                                        onEndRound: () {
                                          _stageTimer?.cancel(); _audioService.stopClip(); _allGuessedTriggered = true;
                                          setState(() => _showReveal = true);
                                          _audioService.setVolume(0.75); _audioService.playFullAtVolume(0.75);
                                        },
                                      ),
                                      if (roundIsOver && room.currentSong != null)
                                        RoundRevealWidget(
                                          roomId: widget.roomId, song: Song.fromMap(room.currentSong!),
                                          isHost: isHost, isSkipped: room.isSkipped,
                                          onNextRound: () {
                                            _stageTimer?.cancel(); _audioService.stopClip(); _audioService.setVolume(1.0);
                                            _allGuessedTriggered = false; 
                                            if (isHost) _gameService.endRound(widget.roomId, room);
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                
                                // 2. Bottom Area: Chat ONLY on Mobile
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(child: GuessHistoryWidget(roomId: widget.roomId, userId: user.uid, roundNumber: room.currentRound)),
                                        GuessInputWidget(roomId: widget.roomId, room: room, userId: user.uid, displayName: displayName, gameService: _gameService),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
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
  final int totalPlayers; // 🆕 Added
  final int correctCount; // 🆕 Added

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
    required this.totalPlayers,
    required this.correctCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (room.isPaused)
          Expanded(
            child: Center(
              child: NeubrutalistContainer(
                color: const Color(0xFFFFFF00),
                padding: EdgeInsets.all(context.fs(20, max: 40)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause_circle_outline, size: context.fs(40, max: 80), color: Colors.black),
                      Gap(context.fs(12, max: 24)),
                      Text('GAME PAUSED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(20, max: 32), color: Colors.black)),
                      const Gap(8),
                      Text(isHost ? 'Resume whenever you are ready.' : 'Waiting for host...', 
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54, fontSize: context.ff(12, max: 14))),
                      if (isHost) ...[
                        Gap(context.fs(16, max: 32)),
                        NeubrutalistButton(label: 'RESUME', color: const Color(0xFF00FF00), onPressed: () => gameService.togglePause(roomId, false)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
        else ...[
          Expanded(
            child: SingleChildScrollView(
              child: ClipPlayerWidget(
                room: room, 
                audioService: audioService, 
                onSongLoad: onSongLoad, 
                isHost: isHost,
                onReveal: (seconds) => gameService.revealMoreClip(roomId, seconds),
                onEndRound: onEndRound,
                totalPlayers: totalPlayers,
                correctPlayersCount: correctCount,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PauseButton extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onToggle;
  const _PauseButton({required this.isPaused, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: NeubrutalistContainer(
        padding: const EdgeInsets.all(8),
        shadowOffset: 0,
        color: isPaused ? Colors.green : Colors.white,
        borderWidth: 2,
        child: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 20, color: isPaused ? Colors.white : Colors.black),
      ),
    );
  }
}

class _ScoreboardButton extends StatelessWidget {
  final String roomId;
  const _ScoreboardButton({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Top Catchers', style: TextStyle(fontWeight: FontWeight.w900)),
            content: SizedBox(
              width: 350,
              height: 450,
              child: ScoreboardWidget(roomId: roomId),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
            ],
          ),
        );
      },
      child: NeubrutalistContainer(
        padding: const EdgeInsets.all(8),
        shadowOffset: 2,
        color: const Color(0xFF00FF00),
        borderWidth: 2,
        child: const Icon(Icons.bar_chart, size: 20, color: Colors.black),
      ),
    );
  }
}

class _SkipVoteButton extends StatelessWidget { 
  final String roomId;
  final String userId;
  final GameService gameService;
  final Room room;
  final int totalPlayers; // 🆕

  const _SkipVoteButton({required this.roomId, required this.userId, required this.gameService, required this.room, required this.totalPlayers});

  @override
  Widget build(BuildContext context) {
    final hasVotedSkip = room.skipVotes.contains(userId);
    final isPlaying = room.status == RoomStatus.playing;
    final bool canStillSkip = room.canSkip;
    
    final votes = room.skipVotes.length;
    final required = (totalPlayers / 2).floor() + 1;

    return GestureDetector(
      onTap: (!isPlaying || hasVotedSkip || !canStillSkip) ? null : () => gameService.voteToSkip(roomId, userId),
      child: NeubrutalistContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: (!canStillSkip) ? Colors.black26 : (hasVotedSkip ? Colors.grey : const Color(0xFFFFFF00)),
        shadowOffset: (hasVotedSkip || !canStillSkip) ? 0 : 2,
        borderWidth: 2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.skip_next, size: 16, color: (hasVotedSkip || !canStillSkip) ? Colors.white70 : Colors.black),
            const SizedBox(width: 4),
            Text(
              !canStillSkip ? 'NO SKIPS LEFT' : (hasVotedSkip ? 'VOTED ($votes/$required)' : 'SKIP ($votes/$required)'), 
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 10, 
                color: (hasVotedSkip || !canStillSkip) ? Colors.white70 : Colors.black
              )
            ),
          ],
        ),
      ),
    );
  }
}
