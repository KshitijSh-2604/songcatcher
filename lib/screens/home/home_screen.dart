import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';
import '../../providers/user_provider.dart';
import '../../providers/room_provider.dart';
import '../../models/app_user.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _codeCtrl = TextEditingController();
  final _gameService = GameService();

  bool _loading = false;
  String? _error;
  String _selectedGenre = 'Bollywood';

  @override
  void initState() {
    super.initState();
    // 🚀 Reset activity status to Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(userServiceProvider).updateActivity(user.uid, 'Home');
      }
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom({bool isPublic = false, bool isPartyMode = false, bool forceLockVisibility = false}) async {
    // Ensure profile is loaded (especially for guests who just arrived)
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile == null) {
      setState(() => _error = 'Profile not loaded. Try again.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roomId = await _gameService.createRoom(
        hostId: userProfile.uid,
        hostName: userProfile.displayName,
        photoUrl: userProfile.photoUrl,
        avatarConfig: userProfile.avatarConfig,
        selectedVibes: [_selectedGenre],
        isPublic: isPublic,
        isPartyMode: isPartyMode,
        forceLockVisibility: forceLockVisibility,
      );
      if (mounted) context.go('/lobby/$roomId');
    } catch (e) {
      setState(() => _error = 'Failed to create room: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickJoin({bool forcePublic = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Ensure profile is loaded
      final userProfile = await ref.read(userProfileProvider.future);
      if (userProfile == null) {
        setState(() => _error = 'Profile not loaded.');
        return;
      }

      final publicRoomId = await _gameService.findPublicRoom(
        userId: userProfile.uid,
        displayName: userProfile.displayName,
        photoUrl: userProfile.photoUrl,
        avatarConfig: userProfile.avatarConfig,
      );

      if (publicRoomId != null) {
        final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(publicRoomId).get();
        final status = roomDoc.data()?['status'] ?? 'waiting';
        
        // Record the room ID for persistence
        ref.read(currentRoomIdProvider.notifier).state = publicRoomId;

        if (mounted) {
          if (status == 'playing' || status == 'roundEnded') {
            context.go('/game/$publicRoomId');
          } else {
            context.go('/lobby/$publicRoomId');
          }
        }
      } else {
        // No public matches found -> Auto-create a public room
        if (mounted) {
          await _createRoom(isPublic: true, forceLockVisibility: forcePublic);
        }
      }
    } catch (e) {
      debugPrint('QuickJoin Error: $e');
      setState(() {
        if (e.toString().contains('index')) {
          _error = 'Database indexing in progress. Please wait 1-2 minutes.';
        } else {
          _error = 'Matchmaking failed: $e';
        }
      });
      if (mounted) setState(() => _loading = false);
    }
  }

  // Removed _showNoMatchesDialog as it's now automated via _createRoom(isPublic: true)

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a room code.');
      return;
    }

    final userProfile = ref.read(userProfileProvider).valueOrNull;
    if (userProfile == null) return;

    setState(() => _loading = true);
    try {
      final roomId = await _gameService.joinRoom(
        code: code,
        userId: userProfile.uid,
        displayName: userProfile.displayName,
        photoUrl: userProfile.photoUrl,
        avatarConfig: userProfile.avatarConfig,
      );
      if (roomId == null) {
        setState(() => _error = 'Room not found.');
      } else {
        if (mounted) context.go('/lobby/$roomId');
      }
    } catch (e) {
      setState(() => _error = 'Failed to join.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 Performance: Only watch registered status and auth object
    final user = ref.watch(currentUserProvider);
    final isGuest = user?.isAnonymous ?? true;

    // Use select to avoid rebuilds on coin or stat changes
    final profileData = ref.watch(userProfileProvider.select((p) => {
      'uid': p.value?.uid,
      'displayName': p.value?.displayName,
      'photoUrl': p.value?.photoUrl,
      'avatarConfig': p.value?.avatarConfig,
      'isEmailVerified': p.value?.isEmailVerified,
      'isPhoneVerified': p.value?.isPhoneVerified,
    }));

    return PageShell(
      showHeader: true,
      showSidebar: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Section ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(context.fs(16, max: 32)),
            child: NeubrutalistContainer(
              color: const Color(0xFFFFFF00),
              borderWidth: 4,
              shadowOffset: 8,
              padding: EdgeInsets.symmetric(
                vertical: context.fs(40, max: 100), 
                horizontal: context.fs(20, max: 60),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -context.fs(20, max: 40),
                    left: -context.fs(10, max: 30),
                    child: Icon(Icons.music_note, color: Colors.black.withOpacity(0.1), size: context.fs(40, max: 80)),
                  ),
                  Positioned(
                    bottom: -context.fs(15, max: 30),
                    right: -context.fs(5, max: 20),
                    child: Icon(Icons.graphic_eq, color: Colors.black.withOpacity(0.1), size: context.fs(40, max: 80)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(
                      'SongCatcher.io',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: context.ff(32, max: 80),
                        color: Colors.black, // Still black in yellow hero box
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: const Duration(milliseconds: 600)).scale(begin: const Offset(0.9, 0.9)),
                    const SizedBox(height: 12),
                    Text(
                      'Catch the beat. Guess the track. Dominate the Arena.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: context.ff(14, max: 22), 
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                        Gap(context.fs(24, max: 48)),
                        if (_loading)
                          Column(
                            children: [
                              const CircularProgressIndicator(color: Colors.black),
                              const SizedBox(height: 12),
                              Text('Finding a match...', 
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black, fontSize: context.ff(12, max: 16))),
                            ],
                          )
                        else
                          SizedBox(
                            width: context.fw(200, max: 320),
                            child: NeubrutalistButton(
                              label: 'QUICK MATCH',
                              color: const Color(0xFF4D4DFF),
                              textColor: Colors.white,
                              onPressed: () => _quickJoin(forcePublic: true),
                            ),
                          ).animate().fadeIn(delay: const Duration(milliseconds: 500)).slideY(begin: 0.2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),

          // ── Match Types ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.fs(16, max: 32)),
            child: context.isMobile 
              ? Column(
                  children: [
                    _MatchTypeCard(
                      icon: Icons.public,
                      label: 'Public Arena',
                      sublabel: 'Join any open match instantly.',
                      iconColor: const Color(0xFF4D4DFF),
                      onTap: () => _quickJoin(),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideY(begin: 0.1),
                    const SizedBox(height: 12),
                    _MatchTypeCard(
                      icon: Icons.vpn_key_outlined,
                      label: 'Host Arena',
                      sublabel: 'Create a room and invite friends.',
                      iconColor: const Color(0xFF00FF00),
                      onTap: () => _createRoom(isPublic: false),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 700)).slideY(begin: 0.1),
                    const SizedBox(height: 12),
                    _MatchTypeCard(
                      icon: Icons.celebration_outlined,
                      label: 'Party Mode',
                      sublabel: 'Songs play only on host device.',
                      iconColor: const Color(0xFFFF00FF),
                      isLocked: !ref.watch(isDevProvider),
                      onTap: () {
                        _createRoom(isPublic: false, isPartyMode: true);
                      },
                    ).animate().fadeIn(delay: const Duration(milliseconds: 800)).slideY(begin: 0.1),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _MatchTypeCard(
                          icon: Icons.public,
                          label: 'Public Arena',
                          sublabel: 'Join any open match instantly.',
                          iconColor: const Color(0xFF4D4DFF),
                          onTap: () => _quickJoin(),
                        ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideX(begin: -0.1),
                      ),
                      Gap(context.fs(12, max: 24), horizontal: true),
                      Expanded(
                        child: _MatchTypeCard(
                          icon: Icons.vpn_key_outlined,
                          label: 'Host Arena',
                          sublabel: 'Create a room and invite friends.',
                          iconColor: const Color(0xFF00FF00),
                          onTap: () => _createRoom(isPublic: false),
                        ).animate().fadeIn(delay: const Duration(milliseconds: 700)).slideX(begin: 0.1),
                      ),
                      Gap(context.fs(12, max: 24), horizontal: true),
                      Expanded(
                        child: _MatchTypeCard(
                          icon: Icons.celebration_outlined,
                          label: 'Party Mode',
                          sublabel: 'Songs play only on host device.',
                          iconColor: const Color(0xFFFF00FF),
                          isLocked: !ref.watch(isDevProvider),
                          onTap: () {
                            if (context.isMobile) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Party Mode hosting is only supported on Desktop/Web.')),
                              );
                              return;
                            }
                            _createRoom(isPublic: false, isPartyMode: true);
                          },
                        ).animate().fadeIn(delay: const Duration(milliseconds: 800)).slideX(begin: 0.2),
                      ),
                    ],
                  ),
                ),
          ),

          Gap(context.fs(16, max: 32)),

          // ── Join with Code ───────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.fs(16, max: 32)),
            child: NeubrutalistContainer(
              padding: EdgeInsets.all(context.fs(12, max: 20)),
              child: Row(
                children: [
                  Icon(Icons.meeting_room, color: Theme.of(context).textTheme.bodyLarge?.color, size: context.fs(20, max: 32)),
                  Gap(context.fs(10, max: 20), horizontal: true),
                  Text('Enter Code:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(14, max: 18), color: Theme.of(context).textTheme.bodyLarge?.color)),
                  Gap(context.fs(10, max: 20), horizontal: true),
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(16, max: 22), letterSpacing: 2, color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        hintText: 'X X X X X X',
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  Gap(context.fs(10, max: 20), horizontal: true),
                  NeubrutalistButton(
                    label: 'JOIN',
                    color: const Color(0xFFFFFF00),
                    onPressed: _joinRoom,
                  ),
                ],
              ),
            ),
          ),

          Gap(context.fs(24, max: 48)),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.fs(16, max: 32)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Your Vibe', style: GoogleFonts.bricolageGrotesque(fontSize: context.ff(20, max: 32), fontWeight: FontWeight.w900)),
                Gap(context.fs(12, max: 24)),
                _VibeGrid(selected: _selectedGenre, onSelect: (g) => setState(() => _selectedGenre = g)),
              ],
            ),
          ),

          Gap(context.fs(24, max: 48)),

          // ── Daily Challenge & Leaderboard ─────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(context.fs(16, max: 32), 0, context.fs(16, max: 32), context.fs(32, max: 60)),
            child: IntrinsicHeight(
              child: AdaptiveRow(
                collapseBelow: 900,
                spacing: context.fs(16, max: 32),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daily Challenge Card
                  NeubrutalistContainer(
                    color: Colors.white,
                    padding: EdgeInsets.all(context.fs(24, max: 48)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wb_sunny_outlined, size: context.fs(40, max: 64), color: Colors.black),
                        const Gap(16),
                        Text(
                          'Daily Challenge',
                          style: GoogleFonts.bricolageGrotesque(fontSize: context.ff(24, max: 32), fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        Text(
                          'Vibe: $_selectedGenre',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: context.ff(14, max: 18), color: const Color(0xFF0001BB)),
                        ),
                        const Gap(24),
                        SizedBox(
                          width: context.fw(180, max: 240),
                          child: NeubrutalistButton(
                            label: isGuest ? 'LOG IN TO UNLOCK' : 'START CHALLENGE',
                            color: const Color(0xFFFFFF00),
                            textColor: Colors.black,
                            onPressed: () {
                              if (isGuest) {
                                context.go('/login');
                                return;
                              }

                              final isVerified = profileData['isEmailVerified'] == true || profileData['isPhoneVerified'] == true;

                              if (!isVerified) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Account Verification Required 🔐', style: TextStyle(fontWeight: FontWeight.w900)),
                                    content: const Text(
                                      'To ensure fair competition and prevent bots, only verified players can take part in the Daily Challenge.\n\n'
                                      'Please verify your Email or link your Phone number in the Profile section to continue.',
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          context.push('/profile');
                                        },
                                        child: const Text('GO TO PROFILE'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              
                              final now = DateTime.now();
                              if (now.hour == 23 && now.minute >= 55) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Arena Maintenance 🛠️', style: TextStyle(fontWeight: FontWeight.w900)),
                                    content: const Text(
                                      'We are currently calculating today\'s results and awarding MusCoins! '
                                      'Daily Challenges will resume at 12:00 AM sharp.'
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                                    ],
                                  ),
                                );
                                return;
                              }
                              
                              context.push('/daily/$_selectedGenre');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Leaderboard Card
                  NeubrutalistContainer(
                    color: Theme.of(context).cardColor,
                    padding: EdgeInsets.all(context.fs(16, max: 32)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.leaderboard_outlined, size: context.fs(20, max: 32)),
                            const Gap(12, horizontal: true),
                            Text('Daily Top Catchers', style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w900, fontSize: context.ff(18, max: 24))),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.open_in_new, size: context.fs(16, max: 24)),
                              onPressed: () => context.go('/leaderboard'),
                              tooltip: 'View Full Leaderboard',
                            ),
                          ],
                        ),
                        Gap(context.fs(12, max: 20)),
                        _DailyLeaderboardPreview(vibe: _selectedGenre),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap(context.fs(40, max: 80)),
        ],
      ),
    );
  }
}

class _DailyLeaderboardPreview extends ConsumerWidget {
  final String vibe;
  const _DailyLeaderboardPreview({required this.vibe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoreVibe = ['Bollywood', 'Punjabi', 'English', 'International'].contains(vibe);
    if (!isCoreVibe) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: context.fs(24, max: 48), color: Colors.black26),
            const Gap(12),
            Text('Leaderboard available for\ncore vibes only.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: context.ff(12, max: 16), color: Theme.of(context).hintColor)),
          ],
        ),
      );
    }

    final leaderboard = ref.watch(dailyLeaderboardProvider(vibe));
    return leaderboard.when(
      data: (attempts) {
        if (attempts.isEmpty) return Center(child: Text('No entries today.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: context.ff(12, max: 16))));
        final displayAttempts = attempts.length > 6 ? attempts.take(6).toList() : attempts;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: displayAttempts.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeubrutalistContainer(
                padding: EdgeInsets.symmetric(horizontal: context.fs(10, max: 16), vertical: context.fs(6, max: 12)),
                shadowOffset: 2,
                child: Row(
                  children: [
                    Text('#${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(12, max: 16))),
                    Gap(context.fs(8, max: 16), horizontal: true),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.displayName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: context.ff(13, max: 18), color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis),
                          Text('${a.correctCount}/5 caught · ${a.totalTries} tries', style: TextStyle(fontSize: context.ff(9, max: 13), fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
                        ],
                      ),
                    ),
                    Text(
                      '${a.score} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: context.ff(12, max: 16),
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        debugPrint('Leaderboard Error: $e');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              e.toString().contains('requires an index') 
                  ? 'Leaderboard requires an index. Check console for link.' 
                  : 'Error loading leaderboard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: context.ff(10, max: 14), fontWeight: FontWeight.w700, color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}

class _MatchTypeCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLocked;

  const _MatchTypeCard({required this.icon, required this.label, required this.sublabel, required this.iconColor, required this.onTap, this.isLocked = false});

  @override
  State<_MatchTypeCard> createState() => _MatchTypeCardState();
}

class _MatchTypeCardState extends State<_MatchTypeCard> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = !widget.isLocked),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.isLocked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLocked ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovering ? Matrix4.diagonal3Values(1.02, 1.02, 1.0) : Matrix4.identity(),
          child: Opacity(
            opacity: widget.isLocked ? 0.6 : 1.0,
            child: NeubrutalistContainer(
              padding: EdgeInsets.all(context.fs(16, max: 32)),
              color: widget.isLocked ? Colors.grey.shade200 : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.isLocked ? Icons.lock_outline : widget.icon, color: widget.isLocked ? Colors.grey : widget.iconColor, size: context.fs(32, max: 64)),
                  Gap(context.fs(12, max: 20)),
                  Text(widget.label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(16, max: 24), color: widget.isLocked ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color)),
                  Gap(context.fs(4, max: 8)),
                  Text(widget.isLocked ? 'COMING SOON' : widget.sublabel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.ff(11, max: 14), color: Theme.of(context).hintColor), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VibeGrid extends StatelessWidget {
  final String selected;
  final Function(String) onSelect;
  const _VibeGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final vibes = ['Bollywood', 'Punjabi', 'English', 'International'];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: vibes.map((v) {
        final isSelected = selected == v;
        return SizedBox(
          width: context.isMobile ? (MediaQuery.of(context).size.width - 44) / 2 : null,
          child: _VibeButton(
            label: v,
            color: isSelected ? const Color(0xFF4D4DFF) : null,
            textColor: isSelected ? Colors.white : null,
            onTap: () => onSelect(v),
          ),
        );
      }).toList(),
    );
  }
}

class _VibeButton extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final VoidCallback onTap;
  const _VibeButton({required this.label, this.color, this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: NeubrutalistContainer(
          color: color ?? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0)),
          shadowOffset: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: textColor ?? (isDark ? Colors.white : Colors.black), fontSize: 14))),
        ),
      ),
    );
  }
}
