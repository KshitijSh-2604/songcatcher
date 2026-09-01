import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/room.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../utils/responsive.dart';
import '../../models/app_user.dart';
import '../../providers/user_provider.dart';
import '../game/widgets/skribbl_avatar.dart';
import '../../services/game_service.dart';

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
  late final ConfettiController _confettiCtrl;
  bool _resultRecorded = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 5));
    _ctrl.forward();
    _maybeRecordResult();
  }

  Future<void> _maybeRecordResult() async {
    if (_resultRecorded) return;
    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final players = ref.read(playersProvider(widget.roomId)).valueOrNull;
      if (players != null && players.isNotEmpty) {
        final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
        final myIndex = sorted.indexWhere((p) => p.id == user.uid);
        if (myIndex != -1) {
          if (myIndex == 0) _confettiCtrl.play(); // 🏆 Play confetti if I won!
          
          final myPlayer = sorted[myIndex];
          setState(() => _resultRecorded = true);
          try {
            await ref.read(userServiceProvider).recordGameResult(user.uid, points: myPlayer.score, rank: myIndex + 1);
          } catch (e) {
            setState(() => _resultRecorded = false);
          }
          return;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _playAgain() async {
    if (_resetting) return;
    
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _resetting = true);
    
    try {
      await ref.read(gameServiceProvider).resetRoomForRematch(widget.roomId, user.uid);
      // The navigation will be handled by the ref.listen on roomProvider
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset lobby: $e'), backgroundColor: Colors.red),
        );
        setState(() => _resetting = false);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final roomAsync    = ref.watch(roomProvider(widget.roomId));
    final user         = ref.watch(currentUserProvider);
    
    ref.listen(roomProvider(widget.roomId), (prev, next) {
      final room = next.valueOrNull;
      if (room != null && room.status == RoomStatus.waiting) {
        if (mounted) context.go('/lobby/${widget.roomId}');
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: playersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (players) {
                  final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
                  final winner = sorted.isNotEmpty ? sorted.first : null;
                  final myRank = sorted.indexWhere((p) => p.id == user?.uid) + 1;
                  final iWon = winner?.id == user?.uid;
                  final isHost = user?.uid == roomAsync.valueOrNull?.hostId;

                  return PageShell(
                    scrollable: true,
                    maxWidth: 1000,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            NeubrutalistButton(
                              label: '← HOME',
                              color: Colors.white,
                              onPressed: () async {
                                final navigator = GoRouter.of(context);
                                ref.read(currentRoomIdProvider.notifier).state = null;
                                if (user != null) {
                                  await ref.read(gameServiceProvider).leaveRoom(widget.roomId, user.uid);
                                }
                                if (mounted) navigator.go('/home');
                              },
                            ),
                            const Spacer(),
                            if (iWon)
                              NeubrutalistContainer(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: const Color(0xFFFFFF00),
                                child: const Row(
                                  children: [
                                    Icon(Icons.emoji_events, size: 20),
                                    SizedBox(width: 8),
                                    Text('CHAMPION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        Gap(context.fs(32, max: 60)),
                        
                        // ── Champion Showcase ────────────────────────────────
                        Center(child: _WinnerBanner(winner: winner, iWon: iWon, myRank: myRank)),
                        
                        Gap(context.fs(40, max: 80)),
                        
                        AdaptiveRow(
                          collapseBelow: 900,
                          children: [
                            // ── Scoreboard ────────────────────────────────────
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Leaderboard', style: GoogleFonts.bricolageGrotesque(fontSize: 24, fontWeight: FontWeight.w900)),
                                const Gap(16),
                                ...sorted.asMap().entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ScoreCard(player: e.value, rank: e.key + 1, isMe: e.value.id == user?.uid),
                                )),
                              ],
                            ),
                            
                            // ── Controls ──────────────────────────────────────
                            Column(
                              children: [
                                NeubrutalistContainer(
                                  color: Theme.of(context).cardColor,
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.refresh, size: 48),
                                      const Gap(16),
                                      const Text('Want a Rematch?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                                      const Gap(8),
                                      const Text('Challenge everyone again with the same settings!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                                      const Gap(24),
                                      if (isHost)
                                        _PlayAgainButton(onPressed: _playAgain, loading: _resetting)
                                      else
                                        const Text('Waiting for Host to start rematch...', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blue)),
                                    ],
                                  ),
                                ),
                                const Gap(24),
                                NeubrutalistButton(
                                  label: 'EXIT TO HOME',
                                  color: const Color(0xFFEEEEEE),
                                  textColor: Colors.black,
                                  onPressed: () async {
                                    final navigator = GoRouter.of(context);
                                    ref.read(currentRoomIdProvider.notifier).state = null;
                                    if (user != null) await ref.read(gameServiceProvider).leaveRoom(widget.roomId, user.uid);
                                    if (mounted) navigator.go('/home');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Gap(48),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // 🎊 Confetti Overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple, Color(0xFFFFFF00)],
              numberOfParticles: 30,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  final Player? winner;
  final bool iWon;
  final int myRank;
  const _WinnerBanner({required this.winner, required this.iWon, required this.myRank});

  @override
  Widget build(BuildContext context) {
    if (winner == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: context.fs(140, max: 220),
              height: context.fs(140, max: 220),
              decoration: BoxDecoration(
                color: iWon ? const Color(0xFFFFFF00) : const Color(0xFFEEEEEE),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 4),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(6, 6))],
              ),
              child: Center(
                child: SkribblAvatar(
                  config: AvatarConfig.fromMap(winner!.avatarConfig),
                  size: context.fs(100, max: 160),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: const Text('🏆', style: TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ),
        const Gap(24),
        Text(
          iWon ? 'YOU WON!' : '${winner!.displayName.toUpperCase()} WINS!',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: context.ff(32, max: 56),
            fontWeight: FontWeight.w900,
            color: iWon ? const Color(0xFF720100) : Colors.black,
          ),
        ),
        const Gap(8),
        NeubrutalistContainer(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: iWon ? const Color(0xFF00FF00) : Colors.black,
          child: Text(
            iWon ? 'AMAZING CATCHING SKILLS!' : 'BETTER LUCK NEXT TIME!',
            style: TextStyle(
              fontWeight: FontWeight.w900, 
              fontSize: context.ff(12, max: 16),
              color: iWon ? Colors.black : Colors.white,
            ),
          ),
        ),
        const Gap(16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WinnerStat(label: 'TOTAL SCORE', value: '${winner!.score}'),
            const Gap(12, horizontal: true),
            _WinnerStat(label: 'SONGS CAUGHT', value: '${winner!.correctGuesses}'),
          ],
        ),
      ],
    );
  }
}

class _WinnerStat extends StatelessWidget {
  final String label;
  final String value;
  const _WinnerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return NeubrutalistContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shadowOffset: 2,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF0001BB))),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final Player player;
  final int rank;
  final bool isMe;
  const _ScoreCard({required this.player, required this.rank, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank.';
    
    return NeubrutalistContainer(
      color: isMe ? const Color(0xFFFFFF00) : Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shadowOffset: 4,
      child: Row(
        children: [
          SizedBox(
            width: 40, 
            child: Text(
              medal, 
              style: TextStyle(
                fontSize: rank <= 3 ? 24 : 18, 
                fontWeight: FontWeight.w900,
                color: rank > 3 ? Colors.black38 : null,
              )
            ),
          ),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white, 
              shape: BoxShape.circle, 
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Center(child: SkribblAvatar(config: AvatarConfig.fromMap(player.avatarConfig), size: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName, 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), 
                  overflow: TextOverflow.ellipsis
                ),
                Text(
                  '${player.correctGuesses} correct guesses', 
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45)
                ),
              ],
            ),
          ),
          // Column(
          //   crossAxisAlignment: CrossAxisAlignment.end,
          //   children: [
          //     Text(
          //       '${player.score}', 
          //       style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0001BB))
          //     ),
          //     const Text('POINTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black26)),
          //   ],
          // ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.score}', 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0001BB))
              ),
              Row(
                children: [
                  if (player.correctGuesses > 0 && (player.totalElapsedMs / player.correctGuesses) < 4000)
                    const _BadgeIcon(icon: Icons.bolt, color: Colors.orange, tooltip: 'Speed Demon'),
                  if (player.hardCorrectGuesses >= 2)
                    const _BadgeIcon(icon: Icons.psychology, color: Colors.purple, tooltip: 'Hardcore'),
                  const Text('POINTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black26)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _BadgeIcon({required this.icon, required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _PlayAgainButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  const _PlayAgainButton({required this.onPressed, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: NeubrutalistButton(
        label: loading ? 'PREPARING LOBBY...' : 'PLAY AGAIN (REMATCH)',
        color: const Color(0xFF00FF00),
        onPressed: loading ? null : onPressed,
      ),
    );
  }
}
