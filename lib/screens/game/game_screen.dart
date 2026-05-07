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
import 'widgets/scoreboard_widget.dart';
import 'widgets/guess_history_widget.dart';

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

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _loadSongIfNeeded(String songId, String audioUrl) async {
    if (_loadedSongId == songId) return;
    _loadedSongId = songId;
    await _audioService.loadSong(audioUrl);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

    return roomAsync.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          return const Scaffold(
              body: Center(child: Text('Room not found')));
        }

        // Navigate to results when game finishes
        if (room.status == RoomStatus.finished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/results/${widget.roomId}');
          });
        }

        final isHost = user?.uid == room.hostId;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('Round ${room.currentRound} / ${room.totalRounds}'),
            centerTitle: true,
            actions: [
              playersAsync.when(
                data: (players) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Chip(
                    avatar: const Icon(Icons.people, size: 16),
                    label: Text('${players.length}'),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;

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
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: ScoreboardWidget(roomId: widget.roomId),
                    ),
                  ],
                );
              }

              // Mobile: stacked layout
              return Column(
                children: [
                  Expanded(
                    child: _GameBody(
                      room: room,
                      roomId: widget.roomId,
                      userId: user!.uid,
                      isHost: isHost,
                      audioService: _audioService,
                      gameService: _gameService,
                      onSongLoad: _loadSongIfNeeded,
                    ),
                  ),
                ],
              );
            },
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
  final bool isHost;
  final SongAudioService audioService;
  final GameService gameService;
  final Future<void> Function(String, String) onSongLoad;

  const _GameBody({
    required this.room,
    required this.roomId,
    required this.userId,
    required this.isHost,
    required this.audioService,
    required this.gameService,
    required this.onSongLoad,
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
          onEndRound: () => gameService.endRound(roomId, room),
        ),
        // Add after ClipPlayerWidget in game_screen.dart, inside the Column:
        if (room.roundStartTime != null)
          RoundTimerWidget(
            roundStartTime: room.roundStartTime!,
            revealedSeconds: room.revealedSeconds,
            isHost: user?.uid == room.hostId,
            onRevealFive: () => _gameService.revealMoreClip(widget.roomId, 5),
            onRevealTen: () => _gameService.revealMoreClip(widget.roomId, 10),
            onRoundEnd: () => _gameService.endRound(widget.roomId, room),
          ),
        const Divider(height: 1),
        Expanded(
          child: GuessHistoryWidget(
            roomId: roomId,
            userId: userId,
          ),
        ),
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