import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/room_provider.dart';
import '../utils/responsive.dart';
import '../screens/game/widgets/skribbl_avatar.dart';
import 'how_to_play_dialog.dart'; // 🆕 Import

class ProfilePopup extends ConsumerWidget {
  const ProfilePopup({super.key});

  void _showHowToPlay(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const HowToPlayDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final user = ref.watch(currentUserProvider);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: NeubrutalistContainer(
        color: bgColor,
        padding: const EdgeInsets.all(20),
        width: 280,
        child: userProfileAsync.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
          data: (userProfile) {
            // Fallback for missing Firestore profile document
            final displayName = userProfile?.displayName ?? user?.displayName ?? 'Player';
            final avatarConfig = userProfile?.avatarConfig ?? {};
            final musCoins = userProfile?.musCoins ?? 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Avatar & Name
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Center(
                            child: SkribblAvatar(
                              config: AvatarConfig.fromMap(avatarConfig),
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 18, 
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Online',
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 32, thickness: 2, color: Colors.black),

                // MusCoins (Link to Marketplace)
                _PopupOption(
                  icon: Icons.monetization_on,
                  iconColor: const Color(0xFFFFFF00),
                  label: 'MusCoins: $musCoins',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marketplace coming soon!')),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // How to Play
                _PopupOption(
                  icon: Icons.help_outline,
                  label: 'How to Play',
                  onTap: () => _showHowToPlay(context),
                ),
                const SizedBox(height: 12),

                // View Full Profile
                _PopupOption(
                  icon: Icons.person_outline,
                  label: 'Edit Profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                const SizedBox(height: 20),

                // Sign Out
                NeubrutalistButton(
                  label: 'SIGN OUT',
                  color: const Color(0xFF720100),
                  textColor: Colors.white,
                  onPressed: () async {
                    ref.read(currentRoomIdProvider.notifier).state = null;
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PopupOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _PopupOption({required this.icon, required this.label, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final itemBg = isDark ? const Color(0xFF262626) : Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: NeubrutalistContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shadowOffset: 2,
          color: itemBg,
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? (isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(width: 12),
              Text(
                label, 
                style: TextStyle(
                  fontWeight: FontWeight.w800, 
                  fontSize: 13, 
                  color: textColor,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.white38 : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
