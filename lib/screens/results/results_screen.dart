import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/player.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../utils/responsive.dart';

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
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
                child: context.twoColumn
                    ? _WideResults(sorted: sorted, winner: winner, iWon: iWon,
                    myRank: myRank, user: user, roomId: widget.roomId)
                    : _NarrowResults(sorted: sorted, winner: winner, iWon: iWon,
                    myRank: myRank, user: user, roomId: widget.roomId),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Narrow layout — stacked, scrollable ─────────────────────────────────────

class _NarrowResults extends StatelessWidget {
  final List<Player> sorted;
  final Player? winner;
  final bool iWon;
  final int myRank;
  final dynamic user;
  final String roomId;

  const _NarrowResults({
    required this.sorted, required this.winner, required this.iWon,
    required this.myRank, required this.user, required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final listHeight = context.screenHeight * 0.4;

    return Column(
      children: [
        Gap(context.fs(8, max: 14)),
        _WinnerBanner(winner: winner, iWon: iWon, myRank: myRank),
        Gap(context.fs(20, max: 32)),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Final Scores',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.ff(15, max: 19))),
        ),
        Gap(context.fs(10, max: 14)),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, __) => Gap(context.fs(6, max: 10)),
            itemBuilder: (_, i) => _ScoreCard(
              player: sorted[i], rank: i + 1, isMe: sorted[i].id == user?.uid,
              animDelay: Duration(milliseconds: i * 80),
            ),
          ),
        ),
        Gap(context.fs(16, max: 24)),
        _ActionButtons(roomId: roomId),
      ],
    );
  }
}

// ── Wide layout — two columns, no scroll ────────────────────────────────────

class _WideResults extends StatelessWidget {
  final List<Player> sorted;
  final Player? winner;
  final bool iWon;
  final int myRank;
  final dynamic user;
  final String roomId;

  const _WideResults({
    required this.sorted, required this.winner, required this.iWon,
    required this.myRank, required this.user, required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.screenHeight * 0.78,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WinnerBanner(winner: winner, iWon: iWon, myRank: myRank),
                Gap(context.fs(24, max: 36)),
                _ActionButtons(roomId: roomId),
              ],
            ),
          ),
          SizedBox(width: context.fs(24, max: 48)),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Final Scores',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.ff(16, max: 20))),
                Gap(context.fs(10, max: 16)),
                Expanded(
                  child: ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => Gap(context.fs(6, max: 10)),
                    itemBuilder: (_, i) => _ScoreCard(
                      player: sorted[i], rank: i + 1, isMe: sorted[i].id == user?.uid,
                      animDelay: Duration(milliseconds: i * 80),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Winner Banner ─────────────────────────────────────────────────────────────

class _WinnerBanner extends StatelessWidget {
  final Player? winner;
  final bool iWon;
  final int myRank;
  const _WinnerBanner({required this.winner, required this.iWon, required this.myRank});

  @override
  Widget build(BuildContext context) {
    if (winner == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.fs(18, max: 32)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: iWon
              ? [Colors.amber.withOpacity(0.25), Colors.orange.withOpacity(0.1)]
              : [Colors.purpleAccent.withOpacity(0.15), Colors.deepPurple.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(context.fs(16, max: 24)),
        border: Border.all(
            color: iWon ? Colors.amber.withOpacity(0.4) : Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(iWon ? '🏆' : '🎵', style: TextStyle(fontSize: context.ff(42, max: 64))),
          Gap(context.fs(8, max: 14)),
          Text(
            iWon ? 'You won!' : '${winner!.displayName} wins!',
            style: TextStyle(
              fontSize: context.ff(19, max: 28),
              fontWeight: FontWeight.w900,
              color: iWon ? Colors.amber : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          Gap(context.fs(5, max: 8)),
          Text(
            iWon ? '🎶 Amazing catching skills!' : 'You finished #$myRank — better luck next round!',
            style: TextStyle(color: Colors.white54, fontSize: context.ff(12, max: 15)),
            textAlign: TextAlign.center,
          ),
          if (iWon) ...[
            Gap(context.fs(12, max: 18)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: context.fs(16, max: 24), vertical: context.fs(7, max: 11)),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Text(
                '${winner!.score} pts · ${winner!.correctGuesses} songs caught',
                style: TextStyle(
                    color: Colors.amber, fontWeight: FontWeight.bold, fontSize: context.ff(12, max: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Score Card ─────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final Player player;
  final int rank;
  final bool isMe;
  final Duration animDelay;

  const _ScoreCard({
    required this.player, required this.rank, required this.isMe, required this.animDelay,
  });

  String get _medal {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank.';
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
        child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.fs(12, max: 20), vertical: context.fs(10, max: 16)),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.purpleAccent.withOpacity(0.12)
              : rank == 1
              ? Colors.amber.withOpacity(0.06)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(context.fs(10, max: 16)),
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
            SizedBox(
              width: context.fs(30, max: 44),
              child: Text(_medal,
                  style: TextStyle(fontSize: context.ff(18, max: 24)), textAlign: TextAlign.center),
            ),
            SizedBox(width: context.fs(6, max: 10)),
            CircleAvatar(
              radius: context.ff(16, max: 22),
              backgroundColor:
              isMe ? Colors.purpleAccent.withOpacity(0.25) : Colors.white.withOpacity(0.08),
              child: Text(player.displayName[0].toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.ff(13, max: 16),
                      color: isMe ? Colors.purpleAccent : Colors.white60)),
            ),
            SizedBox(width: context.fs(10, max: 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(player.displayName,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: context.ff(13, max: 16)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isMe) ...[
                        SizedBox(width: context.fs(5, max: 8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: context.fs(5, max: 8), vertical: context.fs(1, max: 2)),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('you',
                              style: TextStyle(
                                  color: Colors.purpleAccent,
                                  fontSize: context.ff(9, max: 11),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${player.correctGuesses} song${player.correctGuesses == 1 ? '' : 's'} caught',
                    style: TextStyle(color: Colors.white38, fontSize: context.ff(10, max: 12)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${player.score}',
                    style: TextStyle(
                        color: rank == 1 ? Colors.amber : Colors.purpleAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: context.ff(17, max: 22))),
                Text('pts', style: TextStyle(color: Colors.white38, fontSize: context.ff(10, max: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action Buttons ─────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final String roomId;
  const _ActionButtons({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.go('/home'),
            icon: Icon(Icons.replay_rounded, size: context.ff(18, max: 22)),
            label: Text('Play Again', style: TextStyle(fontSize: context.ff(14, max: 16))),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              padding: EdgeInsets.symmetric(vertical: context.fs(12, max: 18)),
            ),
          ),
        ),
        Gap(context.fs(8, max: 12)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: Icon(Icons.home_outlined, size: context.ff(16, max: 20)),
            label: Text('Back to Home', style: TextStyle(fontSize: context.ff(14, max: 16))),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: context.fs(12, max: 18)),
            ),
          ),
        ),
        Gap(context.fs(14, max: 20)),
        Text(
          'songcatcher.io — Catch the song first!',
          style: TextStyle(color: Colors.white24, fontSize: context.ff(10, max: 12), letterSpacing: 0.5),
        ),
      ],
    );
  }
}