import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _resultRecorded = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
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
    setState(() => _resetting = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        // Explicitly use the first person to click play again as host
        await GameService().resetRoomForRematch(widget.roomId, user.uid);
        // Room status will change to waiting, which triggers ref.listen to navigate
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _resetting = false);
      }
    }
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
    
    // Listen for room status reset to 'waiting' - if another player clicks Play Again first
    ref.listen(roomProvider(widget.roomId), (prev, next) {
      final room = next.valueOrNull;
      if (room != null && room.status == RoomStatus.waiting && !_resetting) {
        context.go('/lobby/${widget.roomId}');
      }
    });

    return Scaffold(
      body: SafeArea(
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

              return PageShell(
                scrollable: !context.twoColumn,
                maxWidth: context.twoColumn ? 1000 : 500,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NeubrutalistButton(
                          label: '← HOME',
                          color: Colors.white,
                          onPressed: () {
                            ref.read(currentRoomIdProvider.notifier).state = null;
                            context.go('/home');
                          },
                        ),
                      ],
                    ),
                    const Gap(24),
                    context.twoColumn
                        ? _WideResults(sorted: sorted, winner: winner, iWon: iWon,
                        myRank: myRank, user: user, roomId: widget.roomId, onPlayAgain: _playAgain, resetting: _resetting)
                        : _NarrowResults(sorted: sorted, winner: winner, iWon: iWon,
                        myRank: myRank, user: user, roomId: widget.roomId, onPlayAgain: _playAgain, resetting: _resetting),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NarrowResults extends StatelessWidget {
  final List<Player> sorted;
  final Player? winner;
  final bool iWon;
  final int myRank;
  final dynamic user;
  final String roomId;
  final VoidCallback onPlayAgain;
  final bool resetting;

  const _NarrowResults({
    required this.sorted, required this.winner, required this.iWon,
    required this.myRank, required this.user, required this.roomId,
    required this.onPlayAgain, required this.resetting,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WinnerBanner(winner: winner, iWon: iWon, myRank: myRank),
        const Gap(32),
        _PlayAgainButton(onPressed: onPlayAgain, loading: resetting),
        const Gap(32),
        const Align(alignment: Alignment.centerLeft, child: Text('Final Scores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        const Gap(16),
        ...sorted.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ScoreCard(player: e.value, rank: e.key + 1, isMe: e.value.id == user?.uid),
        )),
        const Gap(32),
        _ActionButtons(roomId: roomId),
      ],
    );
  }
}

class _WideResults extends StatelessWidget {
  final List<Player> sorted;
  final Player? winner;
  final bool iWon;
  final int myRank;
  final dynamic user;
  final String roomId;
  final VoidCallback onPlayAgain;
  final bool resetting;

  const _WideResults({
    required this.sorted, required this.winner, required this.iWon,
    required this.myRank, required this.user, required this.roomId,
    required this.onPlayAgain, required this.resetting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _WinnerBanner(winner: winner, iWon: iWon, myRank: myRank),
              const Gap(32),
              _PlayAgainButton(onPressed: onPlayAgain, loading: resetting),
              const Gap(24),
              _ActionButtons(roomId: roomId),
            ],
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Final Scores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const Gap(16),
              Expanded(
                child: ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ScoreCard(player: sorted[i], rank: i + 1, isMe: sorted[i].id == user?.uid),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayAgainButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  const _PlayAgainButton({required this.onPressed, required this.loading});

  @override
  Widget build(BuildContext context) {
    return NeubrutalistButton(
      label: loading ? 'PREPARING LOBBY...' : 'PLAY AGAIN (LOBBY)',
      color: const Color(0xFF00FF00),
      onPressed: loading ? null : onPressed,
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
    return NeubrutalistContainer(
      color: iWon ? const Color(0xFFFFFF00) : Theme.of(context).cardColor,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(iWon ? '🏆' : '🎵', style: const TextStyle(fontSize: 64)),
          const Gap(16),
          Text(iWon ? 'You won!' : '${winner!.displayName} wins!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Gap(8),
          Text(iWon ? '🎶 Amazing catching skills!' : 'You finished #$myRank — better luck next round!', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (iWon) ...[
            const Gap(16),
            Text('${winner!.score} pts · ${winner!.correctGuesses} songs caught', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0001BB))),
          ],
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
      shadowOffset: 2,
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(medal, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
            child: Center(child: SkribblAvatar(config: AvatarConfig.fromMap(player.avatarConfig), size: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), overflow: TextOverflow.ellipsis)),
          Text('${player.score}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0001BB))),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final String roomId;
  const _ActionButtons({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(currentRoomIdProvider.notifier).state = null;
              context.go('/home');
            },
            icon: const Icon(Icons.home_outlined),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          ),
        ),
      ],
    );
  }
}
