import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_popup.dart';
import 'notification_popup.dart'; // 🔔 New import
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart'; // 🆕 Import
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/responsive.dart';
import '../screens/game/widgets/skribbl_avatar.dart';
import '../models/app_user.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({super.key});

  void _showProfilePopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => Stack(
        children: [
          Positioned(
            top: 75,
            right: 20,
            child: const ProfilePopup(),
          ),
        ],
      ),
    );
  }

  void _showNotificationPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Stack(
        children: [
          Positioned(
            top: 75,
            right: 80, // Slightly to the left of profile
            child: const NotificationPopup(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚀 OPTIMIZATION: Only watch specific fields to prevent unnecessary header rebuilds
    final musCoins = ref.watch(userProfileProvider.select((u) => u.value?.musCoins ?? 0));
    final avatarConfig = ref.watch(userProfileProvider.select((u) => u.value?.avatarConfig));
    final lastReadNotif = ref.watch(userProfileProvider.select((u) => u.value?.lastReadGlobalNotificationAt));
    
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final settings = ref.watch(settingsProvider);

    // 🔔 Unread counts
    int unreadCount = 0;
    if (user != null) {
      final invites = ref.watch(invitesProvider(user.uid)).valueOrNull ?? [];
      final friendRequests = ref.watch(pendingRequestsProvider(user.uid)).valueOrNull ?? [];
      final globalNotifs = ref.watch(globalNotificationsProvider).valueOrNull ?? [];

      unreadCount += invites.where((i) => i['status'] == 'pending').length;
      unreadCount += friendRequests.where((f) => f.requestedBy != user.uid && !f.isRead).length;
      
      unreadCount += globalNotifs.where((g) {
        final ts = (g['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return lastReadNotif == null || ts.isAfter(lastReadNotif);
      }).length;
    }

    return Container(
      height: context.fs(60, max: 90),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
      ),
      padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 24)),
      child: Row(
        children: [
          if (context.isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              color: Theme.of(context).textTheme.bodyLarge?.color,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () => context.go('/home'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'SongCatcher',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: context.ff(16, max: 28),
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0001BB),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (context.isDesktop) ...[
            _HeaderItem(label: 'Daily Challenge', onTap: () => context.push('/daily')),
            Gap(context.fs(12, max: 24), horizontal: true),
            _HeaderItem(label: 'Marketplace', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marketplace coming soon!')),
              );
            }),
            Gap(context.fs(16, max: 32), horizontal: true),
          ],
          _MusCoinsBadge(coins: musCoins),
          Gap(context.fs(8, max: 16), horizontal: true),
          _HeaderIconButton(
            icon: settings.sfxEnabled ? Icons.volume_up : Icons.volume_off,
            onPressed: () => ref.read(settingsProvider.notifier).toggleSfx(),
          ),
          Gap(context.fs(4, max: 8), horizontal: true),
          _HeaderIconButton(
            icon: isDark ? Icons.light_mode : Icons.dark_mode,
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          Gap(context.fs(4, max: 8), horizontal: true),
          _HeaderIconButton(
            icon: Icons.notifications_none,
            badgeCount: unreadCount,
            onPressed: () => _showNotificationPopup(context),
          ),
          Gap(context.fs(8, max: 16), horizontal: true),
          GestureDetector(
            onTap: () => _showProfilePopup(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: context.fs(32, max: 48),
                height: context.fs(32, max: 48),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                ),
                child: Center(
                  child: avatarConfig != null
                    ? SkribblAvatar(
                        config: AvatarConfig.fromMap(avatarConfig),
                        size: context.fs(20, max: 32),
                      )
                    : Icon(Icons.person, color: Theme.of(context).dividerColor, size: context.fs(18, max: 28)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount; // 🔔 New field

  const _HeaderIconButton({required this.icon, required this.onPressed, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            NeubrutalistContainer(
              padding: const EdgeInsets.all(8),
              shadowOffset: 2,
              borderRadius: 8,
              color: Theme.of(context).cardColor,
              child: Icon(icon, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black, offset: Offset(1, 1))],
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _HeaderItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MusCoinsBadge extends StatelessWidget {
  final int coins;
  const _MusCoinsBadge({required this.coins});
  @override
  Widget build(BuildContext context) {
    return NeubrutalistContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shadowOffset: 2,
      borderRadius: 4,
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🚀 Performance: RepaintBoundary for animated coin
          RepaintBoundary(
            child: const Icon(Icons.monetization_on, color: Color(0xFFFFFF00), size: 18)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: const Duration(milliseconds: 2000)),
          ),
          const SizedBox(width: 8),
          Text(
            '$coins',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
