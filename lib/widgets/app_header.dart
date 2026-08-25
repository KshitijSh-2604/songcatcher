import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'profile_popup.dart';
import '../providers/theme_provider.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'SongCatcher.io',
                style: TextStyle(
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: context.ff(20, max: 28),
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0001BB),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (context.isDesktop) ...[
            _HeaderItem(label: 'Daily Challenge', onTap: () => context.push('/daily')),
            const SizedBox(width: 24),
            _HeaderItem(label: 'Marketplace', onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marketplace coming soon!')),
              );
            }),
            const SizedBox(width: 32),
          ],
          _MusCoinsBadge(coins: userProfile?.musCoins ?? 0),
          const SizedBox(width: 16),
          _HeaderIconButton(
            icon: isDark ? Icons.light_mode : Icons.dark_mode,
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.notifications_none,
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _showProfilePopup(context),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).dividerColor, width: 2),
                ),
                child: Center(
                  child: userProfile != null
                    ? SkribblAvatar(
                        config: AvatarConfig.fromMap(userProfile.avatarConfig),
                        size: 30,
                      )
                    : Icon(Icons.person, color: Theme.of(context).dividerColor),
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
  const _HeaderIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: NeubrutalistContainer(
          padding: const EdgeInsets.all(8),
          shadowOffset: 2,
          borderRadius: 8,
          color: Theme.of(context).cardColor,
          child: Icon(icon, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color),
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
          const Icon(Icons.monetization_on, color: Color(0xFFFFFF00), size: 18)
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: const Duration(milliseconds: 2000)),
          const SizedBox(width: 8),
          Text(
            'MusCoins: $coins',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
