import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/daily_challenge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/responsive.dart';
import '../game/widgets/skribbl_avatar.dart';
import '../../models/app_user.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _vibes = ['Bollywood', 'English', 'International'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _vibes.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      showHeader: true,
      showSidebar: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, size: 32, color: Color(0xFFFFFF00)),
                const SizedBox(width: 16),
                Text(
                  'Daily Leaderboard',
                  style: TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: 28, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
                const Spacer(),
                NeubrutalistContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: const Color(0xFF00FF00),
                  shadowOffset: 0,
                  child: const Text('TOP 50', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black)),
                ),
              ],
            ),
          ),

          // ── Tab Bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: NeubrutalistContainer(
              padding: EdgeInsets.zero,
              color: Theme.of(context).cardColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4D4DFF),
                indicatorWeight: 4,
                labelColor: const Color(0xFF4D4DFF),
                unselectedLabelColor: Theme.of(context).hintColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                tabs: _vibes.map((v) => Tab(text: v.toUpperCase())).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Scrollable Content ────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _vibes.map((vibe) => _LeaderboardList(vibe: vibe)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  final String vibe;
  const _LeaderboardList({required this.vibe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(dailyLeaderboardProvider(vibe));
    final currentUser = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).valueOrNull;

    return leaderboardAsync.when(
      data: (attempts) {
        // Find user's rank across all attempts (including beyond top 50 if needed, but provider limits to 50)
        final myIndex = attempts.indexWhere((a) => a.userId == currentUser?.uid);
        final hasPlayed = myIndex != -1;
        
        return Column(
          children: [
            Expanded(
              child: attempts.isEmpty
                  ? _EmptyState(vibe: vibe, hasPlayed: hasPlayed)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemCount: attempts.length,
                      itemBuilder: (context, i) {
                        final a = attempts[i];
                        final isMe = a.userId == currentUser?.uid;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LeaderboardTile(attempt: a, rank: i + 1, isMe: isMe),
                        );
                      },
                    ),
            ),
            // ── Fixed Footer ────────────────────────────────────────────────
            _FixedFooter(
              displayName: userProfile?.displayName ?? 'You',
              avatarConfig: userProfile?.avatarConfig ?? {},
              rank: hasPlayed ? '#${myIndex + 1}' : '--th rank',
              hasPlayed: hasPlayed,
              vibe: vibe,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(error: e.toString()),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Leaderboard Unavailable', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(error.contains('index') ? 'Database index is currently building. Please wait a few minutes.' : 'An error occurred while loading rankings.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final DailyAttempt attempt;
  final int rank;
  final bool isMe;

  const _LeaderboardTile({required this.attempt, required this.rank, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return NeubrutalistContainer(
      color: isMe ? const Color(0xFFFFFF00) : Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shadowOffset: 2,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#$rank',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isMe ? Colors.black : null),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Center(
              child: SkribblAvatar(
                config: AvatarConfig.fromMap(attempt.avatarConfig),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.displayName,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isMe ? Colors.black : null),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${attempt.correctCount}/5 caught · ${attempt.totalTries} tries · ${_formatTime(attempt.totalTimeMs)}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: isMe ? Colors.black54 : Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${attempt.score}',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isMe ? Colors.black : const Color(0xFF4D4DFF)),
              ),
              Text(
                'pts',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: isMe ? Colors.black54 : Theme.of(context).hintColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int ms) {
    final s = ms ~/ 1000;
    final min = s ~/ 60;
    final sec = s % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class _FixedFooter extends StatelessWidget {
  final String displayName;
  final Map<String, dynamic> avatarConfig;
  final String rank;
  final bool hasPlayed;
  final String vibe;

  const _FixedFooter({
    required this.displayName,
    required this.avatarConfig,
    required this.rank,
    required this.hasPlayed,
    required this.vibe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor, width: 2.5),
              ),
              child: Center(
                child: SkribblAvatar(
                  config: AvatarConfig.fromMap(avatarConfig),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Daily Rank: $rank',
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 14, 
                      color: hasPlayed ? const Color(0xFF00FF00) : Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasPlayed)
              NeubrutalistButton(
                label: 'PLAY NOW',
                color: const Color(0xFFFFFF00),
                textColor: Colors.black,
                onPressed: () => context.push('/daily/$vibe'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String vibe;
  final bool hasPlayed;
  const _EmptyState({required this.vibe, required this.hasPlayed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 64, color: Theme.of(context).hintColor.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text(
              'No data available currently.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Play to get your score on leaderboard!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).hintColor.withOpacity(0.5)),
            ),
            if (!hasPlayed) ...[
              const SizedBox(height: 32),
              NeubrutalistButton(
                label: 'START CHALLENGE',
                color: const Color(0xFFFFFF00),
                textColor: Colors.black,
                onPressed: () => context.push('/daily/$vibe'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
