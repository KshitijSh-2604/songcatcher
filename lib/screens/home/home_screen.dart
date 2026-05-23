import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _codeCtrl   = TextEditingController();
  final _gameService = GameService();

  bool    _loading = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final user = ref.read(currentUserProvider)!;
    setState(() { _loading = true; _error = null; });
    try {
      final roomId = await _gameService.createRoom(
        hostId:     user.uid,
        hostName:   user.displayName ?? 'Host',
        genre:      'Mix',
        difficulty: 'medium',
      );
      if (mounted) context.go('/lobby/$roomId');
    } catch (e) {
      setState(() => _error = 'Failed to create room. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) { setState(() => _error = 'Please enter a room code.'); return; }
    if (code.length != 6) { setState(() => _error = 'Room code must be 6 characters.'); return; }

    final user = ref.read(currentUserProvider)!;
    setState(() { _loading = true; _error = null; });
    try {
      final roomId = await _gameService.joinRoom(
        code:        code,
        userId:      user.uid,
        displayName: user.displayName ?? 'Player',
      );
      if (roomId == null) {
        setState(() => _error = 'Room not found or already started.');
      } else {
        if (mounted) context.go('/lobby/$roomId');
      }
    } catch (e) {
      setState(() => _error = 'Failed to join room. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user    = ref.watch(currentUserProvider);
    final isGuest = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SongCatcher'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 48),
                icon: CircleAvatar(
                  radius: 17,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!) : null,
                  backgroundColor: Colors.purpleAccent.withOpacity(0.3),
                  child: user.photoURL == null
                      ? Text(
                    isGuest ? '?' : (user.displayName ?? 'P')[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                      : null,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGuest ? 'Guest' : (user.displayName ?? 'Player'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (!isGuest && user.email != null)
                          Text(user.email!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  if (isGuest)
                    const PopupMenuItem(
                      value: 'register',
                      child: Row(children: [
                        Icon(Icons.person_add_outlined,
                            size: 18, color: Colors.purpleAccent),
                        SizedBox(width: 10),
                        Text('Create Account',
                            style: TextStyle(color: Colors.purpleAccent)),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(children: [
                      Icon(Icons.logout, size: 18, color: Colors.white54),
                      SizedBox(width: 10),
                      Text('Sign Out'),
                    ]),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'logout')   _signOut();
                  if (val == 'register') context.go('/login');
                },
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: context.isDesktop
              ? _DesktopLayout(
            isGuest:    isGuest,
            error:      _error,
            loading:    _loading,
            codeCtrl:   _codeCtrl,
            onCreate:   _createRoom,
            onJoin:     _joinRoom,
            onRegister: () => context.go('/login'),
          )
              : _MobileLayout(
            isGuest:    isGuest,
            error:      _error,
            loading:    _loading,
            codeCtrl:   _codeCtrl,
            onCreate:   _createRoom,
            onJoin:     _joinRoom,
            onRegister: () => context.go('/login'),
          ),
        ),
      ),
    );
  }
}

// ── Desktop layout — two columns, no scroll ────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final bool isGuest;
  final String? error;
  final bool loading;
  final TextEditingController codeCtrl;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onRegister;

  const _DesktopLayout({
    required this.isGuest,
    required this.error,
    required this.loading,
    required this.codeCtrl,
    required this.onCreate,
    required this.onJoin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Left panel: actions ───────────────────────────────
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(large: true),
                    const SizedBox(height: 28),
                    if (isGuest) ...[
                      _GuestBanner(onRegister: onRegister),
                      const SizedBox(height: 20),
                    ],
                    if (error != null) ...[
                      _ErrorBanner(message: error!),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      onPressed: loading ? null : onCreate,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Room'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Join a Room',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          onSubmitted: (_) => onJoin(),
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'Room Code — e.g. XK9P2A',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: loading ? null : onJoin,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 28),
                        ),
                        child: loading
                            ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Text('Join',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(width: 48),

              // ── Right panel: info ─────────────────────────────────
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HowToPlayCard(),
                    const SizedBox(height: 20),
                    _DifficultyGuide(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile/Tablet layout — scrollable ─────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final bool isGuest;
  final String? error;
  final bool loading;
  final TextEditingController codeCtrl;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onRegister;

  const _MobileLayout({
    required this.isGuest,
    required this.error,
    required this.loading,
    required this.codeCtrl,
    required this.onCreate,
    required this.onJoin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    // Max width scales: mobile=440, tablet=600
    final maxW = context.isTablet ? 600.0 : 440.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _HeroCard(large: context.isTablet),
              const SizedBox(height: 28),
              if (isGuest) ...[
                _GuestBanner(onRegister: onRegister),
                const SizedBox(height: 16),
              ],
              if (error != null) ...[
                _ErrorBanner(message: error!),
                const SizedBox(height: 14),
              ],
              FilledButton.icon(
                onPressed: loading ? null : onCreate,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Room'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Join a Room',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    onSubmitted: (_) => onJoin(),
                    decoration: const InputDecoration(
                      hintText: 'Room Code — e.g. XK9P2A',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: loading ? null : onJoin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 22),
                  ),
                  child: loading
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Join'),
                ),
              ]),
              const SizedBox(height: 28),
              _HowToPlayCard(),
              const SizedBox(height: 16),
              _DifficultyGuide(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final bool large;
  const _HeroCard({this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(large ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purpleAccent.withOpacity(0.2),
            Colors.deepPurple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('🎵', style: TextStyle(fontSize: large ? 56 : 44)),
          SizedBox(height: large ? 14 : 10),
          Text(
            'Catch the song first!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: large ? 26 : 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Listen to short clips and guess the song\nbefore your friends do.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white54, fontSize: large ? 15 : 13),
          ),
          SizedBox(height: large ? 20 : 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ClipBadge(seconds: 3,  color: Colors.greenAccent, large: large),
              const SizedBox(width: 8),
              _ClipBadge(seconds: 5,  color: Colors.amberAccent, large: large),
              const SizedBox(width: 8),
              _ClipBadge(seconds: 10, color: Colors.redAccent,   large: large),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClipBadge extends StatelessWidget {
  final int    seconds;
  final Color  color;
  final bool   large;
  const _ClipBadge(
      {required this.seconds, required this.color, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 16 : 12, vertical: large ? 8 : 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '${seconds}s',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: large ? 15 : 13,
        ),
      ),
    );
  }
}

// ── Guest Banner ───────────────────────────────────────────────────────────

class _GuestBanner extends StatelessWidget {
  final VoidCallback onRegister;
  const _GuestBanner({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Colors.amber, size: 16),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'You\'re playing as a guest. Your progress won\'t be saved.',
            style: TextStyle(color: Colors.amber, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onRegister,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              foregroundColor: Colors.amber),
          child: const Text('Register', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Error Banner ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── How to Play Card ───────────────────────────────────────────────────────

class _HowToPlayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How to Play',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          _Step(icon: '🎵', title: 'Hear a clip',
              desc: 'A short audio clip plays — 3s, 5s, or 10s.'),
          const SizedBox(height: 10),
          _Step(icon: '💡', title: 'Guess the song',
              desc: 'Type the song title or artist name.'),
          const SizedBox(height: 10),
          _Step(icon: '⚡', title: 'Score points',
              desc: 'Faster correct guesses earn more points.'),
          const SizedBox(height: 10),
          _Step(icon: '🏆', title: 'Win the round',
              desc: 'Most points after all rounds wins!'),
          // Hidden admin long-press
          const SizedBox(height: 8),
          GestureDetector(
            onLongPress: () => context.go('/admin/seed'),
            child: const Text('songcatcher.io',
                style: TextStyle(color: Colors.white12, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  const _Step({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              Text(desc,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Difficulty Guide ───────────────────────────────────────────────────────

class _DifficultyGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Difficulty Levels',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white70)),
          const SizedBox(height: 10),
          const _DiffRow(emoji: '🟢', label: 'Easy',
              desc: 'Chart-toppers everyone knows'),
          const _DiffRow(emoji: '🟡', label: 'Medium',
              desc: 'Popular but not mega-hits'),
          const _DiffRow(emoji: '🔴', label: 'Hard',
              desc: 'Less mainstream tracks'),
          const _DiffRow(emoji: '💀', label: 'Hardcore',
              desc: 'Deep cuts & obscure songs'),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String desc;
  const _DiffRow(
      {required this.emoji, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Text('$label  ',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12)),
        Expanded(
          child: Text(desc,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ),
      ]),
    );
  }
}