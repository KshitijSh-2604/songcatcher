import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/game_service.dart';

class LobbyScreen extends ConsumerWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomProvider(roomId));
    final playersAsync = ref.watch(playersProvider(roomId));
    final user = ref.watch(currentUserProvider);
    final gameService = GameService();

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) return const Scaffold(body: Center(child: Text('Room not found')));

        // Auto-navigate when game starts
        if (room.status == RoomStatus.playing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/$roomId');
          });
        }

        final isHost = user?.uid == room.hostId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lobby'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Room code card
                    _RoomCodeCard(code: room.code).animate().fadeIn().slideY(begin: -0.1),
                    const SizedBox(height: 24),

                    // Rounds selector (host only)
                    if (isHost) _RoundsSelector(roomId: roomId, room: room, gameService: gameService),
                    const SizedBox(height: 24),

                    // Players list
                    Expanded(
                      child: playersAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('$e'),
                        data: (players) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Players (${players.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: players.length,
                                itemBuilder: (context, i) {
                                  final p = players[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.purpleAccent,
                                      child: Text(p.displayName[0].toUpperCase()),
                                    ),
                                    title: Text(p.displayName),
                                    trailing: p.id == room.hostId
                                        ? const Chip(label: Text('Host'))
                                        : null,
                                  ).animate().fadeIn(delay: (i * 80).ms);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Start button (host only)
                    if (isHost)
                      playersAsync.when(
                        data: (players) => SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: players.length < 2
                                ? null
                                : () => gameService.startGame(roomId),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              players.length < 2
                                  ? 'Waiting for more players...'
                                  : 'Start Game',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      )
                    else
                      const Text(
                        'Waiting for host to start...',
                        style: TextStyle(color: Colors.white54),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  final String code;
  const _RoomCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text('Room Code', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Share this code with friends',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RoundsSelector extends StatelessWidget {
  final String roomId;
  final Room room;
  final GameService gameService;

  const _RoundsSelector({
    required this.roomId,
    required this.room,
    required this.gameService,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Rounds:'),
        const SizedBox(width: 12),
        for (final n in [3, 5, 8, 10])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('$n'),
              selected: room.totalRounds == n,
              selectedColor: Colors.purpleAccent,
              onSelected: (_) => gameService.updateRounds(roomId, n),
            ),
          ),
      ],
    );
  }
}