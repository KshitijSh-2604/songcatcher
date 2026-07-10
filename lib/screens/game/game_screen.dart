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

  Future<void> _loadSongIfNeeded(String songId, String audioUrl, int silenceOffset) async {
    if (_loadedSongId == songId) return;
    _loadedSongId = songId;
    await _audioService.loadSong(audioUrl, silenceOffset: silenceOffset);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
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

        if (room.currentRound != _prevRound) {
          _prevRound = room.currentRound;
          if (_showReveal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _showReveal = false);
            });
          }
        }

        // Round auto-ends when reveal appears — stop showing it once the
        // room moves into "revealed" state server-side too, so late joiners
        // and the host agree on when the round is over.
        final roundIsOver = _showReveal || room.status == RoomStatus.roundEnded;

        final isHost = user?.uid == room.hostId;
        final displayName = user?.displayName ?? 'Player';

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: _RoundIndicator(current: room.currentRound, total: room.totalRounds),
            actions: [
              if (!roundIsOver && room.roundStartedAt != null)
                Padding(
                  padding: EdgeInsets.only(right: context.fs(8, max: 14)),
                  child: RoundTimerWidget(
                    key: ValueKey(room.currentRound),
                    roundStartTime: room.roundStartedAt!.toDate(),
                    revealedSeconds: room.revealedSeconds,
                    isHost: isHost,
                    onRevealThree: () => _gameService.revealMoreClip(widget.roomId, 3),
                    onRevealFive: () => _gameService.revealMoreClip(widget.roomId, 5),
                    onRevealTen: () => _gameService.revealMoreClip(widget.roomId, 10),
                    onRoundEnd: () {
                      if (!_showReveal) setState(() => _showReveal = true);
                      _gameService.forceEndRoundIfActive(widget.roomId);
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
                    onSongLoad: _loadSongIfNeeded,
                    onEndRound: () => setState(() => _showReveal = true),
                  );

                  if (!isWide) return body;

                  final sidebarWidth = (constraints.maxWidth * 0.22).clamp(180.0, 280.0);

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
                  onNextRound: () => _gameService.endRound(widget.roomId, room),
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
        Text('Round $current / $total', style: TextStyle(fontSize: context.ff(14, max: 18))),
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
        label: Text('${players.length}', style: TextStyle(fontSize: context.ff(12, max: 14))),
        visualDensity: VisualDensity.compact,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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