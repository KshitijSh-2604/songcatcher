import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String roomId;
  const ResultsScreen({super.key, required this.roomId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: playersAsync.when(
            loading: () =>
            const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error: $e')),
            data: (players) {
              final sorted = [...players]
                ..sort((a, b) => b.score.compareTo(a.score));

              final winner =
              sorted.isNotEmpty ? sorted.first : null;
              final myRank =
                  sorted.indexWhere((p) => p.id == user?.uid) + 1;
              final iWon = winner?.id == user?.uid;

              return Center(
                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // ── Winner Banner ─────────────────────────────
                        _WinnerBanner(
                          winner: winner,
                          iWon: iWon,
                          myRank: myRank,
                        ),
                        const SizedBox(height: 28),

                        // ── Final Scores Header ───────────────────────
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Final Scores',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Scores List ───────────────────────────────
                        Expanded(
                          child: ListView.separated(
                            itemCount: sorted.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final p = sorted[i];
                              final isMe = p.id == user?.uid;
                              return _ScoreCard(
                                player: p,
                                rank: i + 1,
                                isMe: isMe,
                                animDelay:
                                Duration(milliseconds: i * 80),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Actions ───────────────────────────────────
                        _ActionButtons(roomId: widget.roomId),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Winner Banner ──────────────────────────────────────────────────────────

class _WinnerBanner extends StatelessWidget {
  final Player? winner;
  final bool iWon;
  final int myRank;

  const _WinnerBanner({
    required this.winner,
    required this.iWon,
    required this.myRank,
  });

  @override
  Widget build(BuildContext context) {
    if (winner == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: iWon
              ? [
            Colors.amber.withOpacity(0.25),
            Colors.orange.withOpacity(0.1),
          ]
              : [
            Colors.purpleAccent.withOpacity(0.15),
            Colors.deepPurple.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: iWon
              ? Colors.amber.withOpacity(0.4)
              : Colors.purpleAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            iWon ? '🏆' : '🎵',
            style: const TextStyle(fontSize: 52),
          ),
          const SizedBox(height: 10),
          Text(
            iWon
                ? 'You won!'
                : '${winner!.displayName} wins!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: iWon ? Colors.amber : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            iWon
                ? '🎶 Amazing catching skills!'
                : 'You finished #$myRank — better luck next round!',
            style: const TextStyle(
                color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),

          // Winner's score highlight
          if (iWon) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.amber.withOpacity(0.4)),
              ),
              child: Text(
                '${winner!.score} pts · ${winner!.correctGuesses} songs caught',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Score Card ─────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final Player player;
  final int rank;
  final bool isMe;
  final Duration animDelay;

  const _ScoreCard({
    required this.player,
    required this.rank,
    required this.isMe,
    required this.animDelay,
  });

  String get _medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 16),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.purpleAccent.withOpacity(0.12)
              : rank == 1
              ? Colors.amber.withOpacity(0.06)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? Colors.purpleAccent.withOpacity(0.5)
                : rank == 1
                ? Colors.amber.withOpacity(0.25)
                : Colors.white12,
            width: isMe ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Medal / rank
            SizedBox(
              width: 40,
              child: Text(
                _medal,
                style: const TextStyle(fontSize: 22),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: isMe
                  ? Colors.purpleAccent.withOpacity(0.25)
                  : Colors.white.withOpacity(0.08),
              child: Text(
                player.displayName[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMe
                      ? Colors.purpleAccent
                      : Colors.white60,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        player.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent
                                .withOpacity(0.2),
                            borderRadius:
                            BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'you',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${player.correctGuesses} song${player.correctGuesses == 1 ? '' : 's'} caught',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.score}',
                  style: TextStyle(
                    color: rank == 1
                        ? Colors.amber
                        : Colors.purpleAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const Text(
                  'pts',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Buttons ─────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final String roomId;
  const _ActionButtons({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Play again (goes back to home — host creates new room)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Play Again'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              padding:
              const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Back to home
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Fun footer
        const Text(
          'songcatcher.io — Catch the song first!',
          style: TextStyle(
            color: Colors.white24,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}