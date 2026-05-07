import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';

class ResultsScreen extends ConsumerWidget {
  final String roomId;
  const ResultsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersProvider(roomId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: playersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (players) {
            final winner = players.isNotEmpty ? players.first : null;
            final me = players.where((p) => p.id == currentUser?.uid).firstOrNull;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Trophy icon
                      const Text('🏆', style: TextStyle(fontSize: 72))
                          .animate()
                          .scale(duration: 700.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 12),

                      Text(
                        'Game Over!',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      if (winner != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${winner.displayName} wins with ${winner.score} pts!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ).animate().fadeIn(delay: 500.ms),
                      ],

                      // My score highlight
                      if (me != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.purpleAccent.withOpacity(0.4)),
                          ),
                          child: Text(
                            'Your score: ${me.score} pts  (#${players.indexOf(me) + 1})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                      ],

                      const SizedBox(height: 32),

                      // Full leaderboard
                      Expanded(
                        child: _Leaderboard(players: players, currentUserId: currentUser?.uid),
                      ),

                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.go('/home'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Home'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => context.go('/home'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Play Again'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  final List<Player> players;
  final String? currentUserId;

  const _Leaderboard({required this.players, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇', '🥈', '🥉'];

    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final isMe = p.id == currentUserId;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: i == 0
                ? Colors.amber.withOpacity(0.12)
                : isMe
                ? Colors.purpleAccent.withOpacity(0.1)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: i == 0
                  ? Colors.amber.withOpacity(0.4)
                  : isMe
                  ? Colors.purpleAccent.withOpacity(0.3)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Text(
                i < 3 ? medals[i] : '${i + 1}.',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.purpleAccent.withOpacity(0.3),
                child: Text(p.displayName[0].toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.displayName + (isMe ? ' (You)' : ''),
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Text(
                '${p.score} pts',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: i == 0 ? Colors.amber : Colors.white,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (i * 100).ms).slideX(begin: 0.1);
      },
    );
  }
}