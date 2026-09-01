import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';
import '../providers/user_provider.dart';
import '../services/game_service.dart';
import '../providers/room_provider.dart';

class NeubrutalistSidebar extends ConsumerWidget {
  const NeubrutalistSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentRoomId = ref.watch(currentRoomIdProvider);
    
    // 🚀 Performance: Only watch registered status and name
    final user = ref.watch(currentUserProvider);
    final isGuest = user?.isAnonymous ?? true;
    final displayName = ref.watch(userProfileProvider.select((p) => p.value?.displayName));

    // 🔔 Count pending unread friend requests for the bubble
    final pendingRequestsCount = user == null ? 0 : ref.watch(pendingRequestsProvider(user.uid)).when(
      data: (reqs) => reqs.where((f) => f.requestedBy != user.uid && !f.isRead).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final String titleText = (!isGuest && displayName != null) 
        ? 'Hello, $displayName' 
        : 'Music Arena';
    final String subtitleText = (!isGuest && displayName != null)
        ? 'Welcome back'
        : 'Catch the beat!';

    return Container(
      width: context.fw(240, max: 320),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fixed Header ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.fs(12, max: 20),
              context.fs(16, max: 32),
              context.fs(12, max: 20),
              context.fs(12, max: 20),
            ),
            child: Row(
              children: [
                NeubrutalistContainer(
                  padding: const EdgeInsets.all(4),
                  color: isDark ? Colors.white : Colors.black,
                  shadowOffset: 0,
                  child: Icon(Icons.music_note, color: isDark ? Colors.black : Colors.white, size: context.fs(20, max: 32)),
                ),
                Gap(context.fs(10, max: 16), horizontal: true),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titleText,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: context.ff(15, max: 20),
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: context.ff(10, max: 13), 
                          fontWeight: FontWeight.w700, 
                          color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Navigation Items ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
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
                    badgeCount: pendingRequestsCount, // 🔔 Pass count
                    onTap: () => context.go('/friends'),
                  ),
                  _SidebarItem(
                    icon: Icons.emoji_events_outlined,
                    label: 'Achievements',
                    isActive: currentRoute == '/achievements',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // ── Fixed Footer ──────────────────────────────────────────────
          Divider(height: 1, color: Theme.of(context).dividerColor, thickness: 2),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: NeubrutalistButton(
                        label: 'Profile',
                        color: const Color(0xFFFFFF00),
                        textColor: Colors.black,
                        onPressed: () => context.push('/profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: NeubrutalistButton(
                        label: 'Sign Out',
                        color: Colors.white,
                        textColor: Colors.black,
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w900)),
                              content: const Text('Are you sure you want to leave the Arena?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('STAY')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('SIGN OUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            // Clear states
                            ref.read(currentRoomIdProvider.notifier).state = null;
                            
                            // Sign out from Firebase and Google (if applicable)
                            await FirebaseAuth.instance.signOut();
                            await GoogleSignIn().signOut();
                            
                            if (context.mounted) context.go('/login');
                          }
                        },
                      ),
                    ),
                  ],
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
                  TextButton(
                    onPressed: () async {
                      await GameService().nukeAllRooms();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All active rooms have been purged!'))
                        );
                      }
                    },
                    child: const Text('🧨 NUKE ALL ROOMS', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ),
                  TextButton(
                    onPressed: () => _showGlobalNotificationDialog(context, ref),
                    child: const Text('📢 SEND GLOBAL NOTIF', style: TextStyle(fontSize: 10, color: Colors.blue)),
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

  void _showGlobalNotificationDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Global Notification', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Heading')),
            const SizedBox(height: 12),
            TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: 'Body'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
              final user = ref.read(currentUserProvider);
              await ref.read(userServiceProvider).sendGlobalNotification(
                title: titleCtrl.text.trim(),
                body: bodyCtrl.text.trim(),
                senderName: user?.displayName ?? 'Admin',
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification broadcasted!')));
              }
            },
            child: const Text('SEND TO ALL'),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int badgeCount; // 🔔 New field
  final VoidCallback? onTap;

  const _SidebarItem({required this.icon, required this.label, required this.isActive, this.badgeCount = 0, this.onTap});

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
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 14, 
                      color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
