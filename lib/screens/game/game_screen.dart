import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/audio_service.dart';
import '../../services/game_service.dart';
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
  final _gameService = GameService();

  String? _loadedSongId;
  bool _navigating = false;
  bool _showReveal = false;
  int _prevRound = 0;

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadSongIfNeeded(
      String songId, String audioUrl, int silenceOffset) async {
    if (_loadedSongId == songId) return;
    _loadedSongId = songId;
    await _audioService.loadSong(audioUrl,
        silenceOffset: silenceOffset);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

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

        // Navigate to results when game finishes
        if (room.status == RoomStatus.finished && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/results/${widget.roomId}');
          });
        }

        // Detect round change — hide reveal overlay
        if (room.currentRound != _prevRound) {
          _prevRound = room.currentRound;
          if (_showReveal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _showReveal = false);
            });
          }
        }

        final isHost = user?.uid == room.hostId;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: _RoundIndicator(
              current: room.currentRound,
              total: room.totalRounds,
            ),
            actions: [
              _PlayerCountBadge(roomId: widget.roomId),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              // ── Main game layout ──────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 680;

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _GameBody(
                            room: room,
                            roomId: widget.roomId,
                            userId: user!.uid,
                            isHost: isHost,
                            audioService: _audioService,
                            gameService: _gameService,
                            onSongLoad: _loadSongIfNeeded,
                            onEndRound: () => setState(
                                    () => _showReveal = true),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 210,
                          child: ScoreboardWidget(
                              roomId: widget.roomId),
                        ),
                      ],
                    );
                  }

                  return _GameBody(
                    room: room,
                    roomId: widget.roomId,
                    userId: user!.uid,
                    isHost: isHost,
                    audioService: _audioService,
                    gameService: _gameService,
                    onSongLoad: _loadSongIfNeeded,
                    onEndRound: () =>
                        setState(() => _showReveal = true),
                  );
                },
              ),

              // ── Round reveal overlay ──────────────────────────────
              if (_showReveal && room.currentSongId != null)
                RoundRevealWidget(
                  roomId: widget.roomId,
                  songId: room.currentSongId!,
                  isHost: isHost,
                  onNextRound: () {
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

// ── Round Indicator ────────────────────────────────────────────────────────

class _RoundIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _RoundIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎵 '),
        Text('Round $current / $total'),
      ],
    );
  }
}

// ── Player Count Badge ─────────────────────────────────────────────────────

class _PlayerCountBadge extends ConsumerWidget {
  final String roomId;
  const _PlayerCountBadge({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersProvider(roomId));
    return playersAsync.when(
      data: (players) => Chip(
        avatar: const Icon(Icons.people, size: 14),
        label: Text('${players.length}'),
        visualDensity: VisualDensity.compact,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Game Body ──────────────────────────────────────────────────────────────

class _GameBody extends StatelessWidget {
  final Room room;
  final String roomId;
  final String userId;
  final bool isHost;
  final SongAudioService audioService;
  final GameService gameService;
  final Future<void> Function(String, String, int) onSongLoad;
  final VoidCallback onEndRound;

  const _GameBody({
    required this.room,
    required this.roomId,
    required this.userId,
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
        // Clip player
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

        // Guess history
        Expanded(
          child: GuessHistoryWidget(
            roomId: roomId,
            userId: userId,
          ),
        ),

        // Guess input
        GuessInputWidget(
          roomId: roomId,
          room: room,
          userId: userId,
          gameService: gameService,
        ),
      ],
    );
  }
}