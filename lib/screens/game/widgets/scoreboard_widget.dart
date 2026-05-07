import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/room_provider.dart';

class ScoreboardWidget extends ConsumerWidget {
  final String roomId;
  const ScoreboardWidget({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersProvider(roomId));
    final currentUser = ref.watch(currentUserProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(left: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            alignment: Alignment.center,
            child: const Text(
              'Scoreboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: playersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (players) => ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, i) {
                  final p = players[i];
                  final isMe = p.id == currentUser?.uid;
                  final medals = ['🥇', '🥈', '🥉'];

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.purpleAccent.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMe
                            ? Colors.purpleAccent.withOpacity(0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Text(
                        i < 3 ? medals[i] : '${i + 1}.',
                        style: const TextStyle(fontSize: 16),
                      ),
                      title: Text(
                        p.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          color: isMe ? Colors.purpleAccent : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '${p.score}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: p.hasGuessedCorrectly ? Colors.green : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ).animate(key: ValueKey(p.id)).fadeIn(delay: (i * 50).ms);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}