import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';
import '../../providers/user_provider.dart';
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
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom({bool isPublic = false}) async {
    final userProfile = ref.read(userProfileProvider).valueOrNull;
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
      );
      if (mounted) context.go('/lobby/$roomId');
    } catch (e) {
      setState(() => _error = 'Failed to create room.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickJoin() async {
    final userProfile = ref.read(userProfileProvider).valueOrNull;
    if (userProfile == null) {
      setState(() => _error = 'Profile not loaded.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final publicRoomId = await _gameService.findPublicRoom(
        userId: userProfile.uid,
        displayName: userProfile.displayName,
        photoUrl: userProfile.photoUrl,
        avatarConfig: userProfile.avatarConfig,
      );

      if (publicRoomId != null) {
        final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(publicRoomId).get();
        final status = roomDoc.data()?['status'] ?? 'waiting';
        
        if (mounted) {
          if (status == 'playing' || status == 'roundEnded') {
            context.go('/game/$publicRoomId');
          } else {
            context.go('/lobby/$publicRoomId');
          }
        }
      } else {
        if (mounted) {
          setState(() => _loading = false);
          _showNoMatchesDialog();
        }
      }
    } catch (e) {
      setState(() => _error = 'Matchmaking failed. Try again.');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNoMatchesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Public Matches', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('There are no open public matches right now. Would you like to start one and wait for players?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createRoom(isPublic: true);
            },
            child: const Text('START PUBLIC MATCH'),
          ),
        ],
      ),
    );
  }

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
    final user = ref.watch(currentUserProvider);
    final isGuest = user?.isAnonymous ?? true;

    return PageShell(
      showHeader: true,
      showSidebar: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero Section ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: NeubrutalistContainer(
              color: const Color(0xFFFFFF00),
              borderWidth: 4,
              shadowOffset: 8,
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -30,
                    left: -20,
                    child: Icon(Icons.music_note, color: Colors.black.withOpacity(0.1), size: 60),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -10,
                    child: Icon(Icons.graphic_eq, color: Colors.black.withOpacity(0.1), size: 60),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(
                      'SongCatcher.io',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: context.ff(40, max: 70),
                        color: Colors.black, // Still black in yellow hero box
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: const Duration(milliseconds: 600)).scale(begin: const Offset(0.9, 0.9)),
                    const SizedBox(height: 12),
                    const Text(
                      'Catch the beat. Guess the track. Dominate the Arena.',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
                        const SizedBox(height: 40),
                        if (_loading)
                          const Column(
                            children: [
                              CircularProgressIndicator(color: Colors.black),
                              SizedBox(height: 12),
                              Text('Finding a match...', 
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
                            ],
                          )
                        else
                          SizedBox(
                            width: 240,
                            child: NeubrutalistButton(
                              label: 'QUICK MATCH',
                              color: const Color(0xFF4D4DFF),
                              textColor: Colors.white,
                              onPressed: _quickJoin,
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MatchTypeCard(
                      icon: Icons.public,
                      label: 'Public Arena',
                      sublabel: 'Join any open match instantly.',
                      iconColor: const Color(0xFF4D4DFF),
                      onTap: _quickJoin,
                    ).animate().fadeIn(delay: const Duration(milliseconds: 600)).slideX(begin: -0.1),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _MatchTypeCard(
                      icon: Icons.vpn_key_outlined,
                      label: 'Host Arena',
                      sublabel: 'Create a room and invite friends.',
                      iconColor: const Color(0xFF00FF00),
                      onTap: () => _createRoom(isPublic: false),
                    ).animate().fadeIn(delay: const Duration(milliseconds: 700)).slideX(begin: 0.1),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Join with Code ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: NeubrutalistContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.meeting_room, color: Theme.of(context).textTheme.bodyLarge?.color, size: 24),
                  const SizedBox(width: 16),
                  Text('Enter Code:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, color: Theme.of(context).textTheme.bodyLarge?.color),
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
                  const SizedBox(width: 16),
                  NeubrutalistButton(
                    label: 'JOIN',
                    color: const Color(0xFFFFFF00),
                    onPressed: _joinRoom,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Your Vibe', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),
                _VibeGrid(selected: _selectedGenre, onSelect: (g) => setState(() => _selectedGenre = g)),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Daily Challenge & Leaderboard ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: IntrinsicHeight(
              child: AdaptiveRow(
                collapseBelow: 900,
                spacing: 24,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daily Challenge Card
                  NeubrutalistContainer(
                    color: Colors.white,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 48, color: Colors.black),
                        const SizedBox(height: 16),
                        const Text(
                          'Daily Challenge',
                          style: TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        Text(
                          'Vibe: $_selectedGenre',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0001BB)),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 220,
                          child: NeubrutalistButton(
                            label: isGuest ? 'LOG IN TO UNLOCK' : 'START CHALLENGE',
                            color: const Color(0xFFFFFF00),
                            textColor: Colors.black,
                            onPressed: () {
                              if (isGuest) {
                                context.go('/login');
                                return;
                              }

                              final profile = ref.read(userProfileProvider).valueOrNull;
                              final isVerified = profile?.isEmailVerified == true || profile?.isPhoneVerified == true;

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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.leaderboard_outlined, size: 24),
                            const SizedBox(width: 12),
                            const Text('Daily Top Catchers', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w900, fontSize: 22)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 18),
                              onPressed: () => context.go('/leaderboard'),
                              tooltip: 'View Full Leaderboard',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DailyLeaderboardPreview(vibe: _selectedGenre),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
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
    final isCoreVibe = ['Bollywood', 'English', 'International'].contains(vibe);
    if (!isCoreVibe) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 32, color: Colors.black26),
            const SizedBox(height: 12),
            Text('Leaderboard available for\ncore vibes only.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
          ],
        ),
      );
    }

    final leaderboard = ref.watch(dailyLeaderboardProvider(vibe));
    return leaderboard.when(
      data: (attempts) {
        if (attempts.isEmpty) return Center(child: Text('No entries today.', style: TextStyle(color: Theme.of(context).hintColor)));
        final displayAttempts = attempts.length > 6 ? attempts.take(6).toList() : attempts;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: displayAttempts.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeubrutalistContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shadowOffset: 2,
                child: Row(
                  children: [
                    Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.displayName, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis),
                          Text('${a.correctCount}/5 caught · ${a.totalTries} tries', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
                        ],
                      ),
                    ),
                    Text(
                      '${a.score} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red),
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

  const _MatchTypeCard({required this.icon, required this.label, required this.sublabel, required this.iconColor, required this.onTap});

  @override
  State<_MatchTypeCard> createState() => _MatchTypeCardState();
}

class _MatchTypeCardState extends State<_MatchTypeCard> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovering ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
          child: NeubrutalistContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.iconColor, size: 48),
                const SizedBox(height: 16),
                Text(widget.label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 8),
                Text(widget.sublabel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).hintColor), textAlign: TextAlign.center),
              ],
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
    final vibes = ['Bollywood', 'English', 'International'];
    return Row(
      children: vibes.map((v) {
        final isSelected = selected == v;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: v == vibes.last ? 0 : 12),
            child: _VibeButton(
              label: v,
              color: isSelected ? const Color(0xFF4D4DFF) : null,
              textColor: isSelected ? Colors.white : null,
              onTap: () => onSelect(v),
            ),
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
