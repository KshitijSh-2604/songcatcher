import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';
import '../providers/user_provider.dart';

import '../providers/room_provider.dart';

class NeubrutalistSidebar extends ConsumerWidget {
  const NeubrutalistSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentRoomId = ref.watch(currentRoomIdProvider);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                NeubrutalistContainer(
                  padding: const EdgeInsets.all(4),
                  color: isDark ? Colors.white : Colors.black,
                  shadowOffset: 0,
                  child: Icon(Icons.music_note, color: isDark ? Colors.black : Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SongCatcher.io',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        'Guess the Beat!',
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.w700, 
                          color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SidebarItem(
            icon: Icons.stadium_outlined,
            label: 'Arena',
            isActive: currentRoute == '/home',
            onTap: () {
              ref.read(currentRoomIdProvider.notifier).state = null;
              context.go('/home');
            },
          ),
          _SidebarItem(
            icon: Icons.meeting_room_outlined,
            label: 'Lobby',
            isActive: currentRoute.contains('/lobby') || currentRoute.contains('/game'),
            onTap: currentRoomId == null ? null : () {
              // Always return to the current active room (Lobby or Game)
              context.go('/lobby/$currentRoomId');
            },
          ),
          _SidebarItem(
            icon: Icons.leaderboard_outlined,
            label: 'Leaderboard',
            isActive: currentRoute == '/leaderboard',
            onTap: () => context.go('/leaderboard'),
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            label: 'Friends',
            isActive: currentRoute == '/friends',
            onTap: () {},
          ),
          _SidebarItem(
            icon: Icons.emoji_events_outlined,
            label: 'Achievements',
            isActive: currentRoute == '/achievements',
            onTap: () {},
          ),
          const Spacer(),
          Divider(height: 1, color: Theme.of(context).dividerColor, thickness: 2),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                NeubrutalistButton(
                  label: 'Profile',
                  color: const Color(0xFFFFFF00),
                  textColor: Colors.black,
                  onPressed: () => context.push('/profile'),
                ),
                if (ref.watch(isDevProvider)) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await ref.read(dailyChallengeServiceProvider).clearTodayAttempts();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Global daily attempts cleared for today!'))
                        );
                      }
                    },
                    child: Text('Reset Global Dailies', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _SidebarItem({required this.icon, required this.label, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onTap == null && !isActive;

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: isDisabled ? 0.4 : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF4D4DFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isActive ? Border.all(color: Theme.of(context).dividerColor, width: 2) : null,
            ),
            child: Row(
              children: [
                Icon(icon, 
                    color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87), 
                    size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800, 
                    fontSize: 14, 
                    color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
