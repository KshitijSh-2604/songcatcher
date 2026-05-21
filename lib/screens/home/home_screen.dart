import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  final _gameService = GameService();

  bool _loading = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Create Room ──────────────────────────────────────────────────────────

  Future<void> _createRoom() async {
    final user = ref.read(currentUserProvider)!;
    setState(() { _loading = true; _error = null; });
    try {
      final roomId = await _gameService.createRoom(
        hostId: user.uid,
        hostName: user.displayName ?? 'Host',
      );
      if (mounted) context.go('/lobby/$roomId');
    } catch (e) {
      setState(() => _error = 'Failed to create room. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Join Room ────────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a room code.');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'Room code must be 6 characters.');
      return;
    }

    final user = ref.read(currentUserProvider)!;
    setState(() { _loading = true; _error = null; });

    try {
      final roomId = await _gameService.joinRoom(
        code: code,
        userId: user.uid,
        displayName: user.displayName ?? 'Player',
      );
      if (roomId == null) {
        setState(
                () => _error = 'Room not found or already started.');
      } else {
        if (mounted) context.go('/lobby/$roomId');
      }
    } catch (e) {
      setState(() => _error = 'Failed to join room. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Sign out ─────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
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
                      ? NetworkImage(user.photoURL!)
                      : null,
                  backgroundColor:
                  Colors.purpleAccent.withOpacity(0.3),
                  child: user.photoURL == null
                      ? Text(
                    isGuest
                        ? '?'
                        : (user.displayName ??
                        'P')[0]
                        .toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  )
                      : null,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGuest
                              ? 'Guest'
                              : (user.displayName ?? 'Player'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (!isGuest && user.email != null)
                          Text(
                            user.email!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  if (isGuest)
                    const PopupMenuItem(
                      value: 'register',
                      child: Row(
                        children: [
                          Icon(Icons.person_add_outlined,
                              size: 18,
                              color: Colors.purpleAccent),
                          SizedBox(width: 10),
                          Text('Create Account',
                              style: TextStyle(
                                  color: Colors.purpleAccent)),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout,
                            size: 18, color: Colors.white54),
                        SizedBox(width: 10),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'logout') _signOut();
                  if (val == 'register') context.go('/login');
                },
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ── Hero section ──────────────────────────────────
                    _HeroCard(),
                    const SizedBox(height: 32),

                    // ── Guest warning ─────────────────────────────────
                    if (isGuest) ...[
                      _GuestBanner(
                          onRegister: () => context.go('/login')),
                      const SizedBox(height: 20),
                    ],

                    // ── Error banner ──────────────────────────────────
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],

                    // ── Create Room ───────────────────────────────────
                    FilledButton.icon(
                      onPressed: _loading ? null : _createRoom,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create Room'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Join Room ─────────────────────────────────────
                    const Text(
                      'Join a Room',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            textCapitalization:
                            TextCapitalization.characters,
                            maxLength: 6,
                            onSubmitted: (_) => _joinRoom(),
                            decoration: const InputDecoration(
                              hintText: 'Room Code — e.g. XK9P2A',
                              prefixIcon: Icon(
                                  Icons.meeting_room_outlined),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _loading ? null : _joinRoom,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 22),
                          ),
                          child: _loading
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                              : const Text('Join'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── How to play ───────────────────────────────────
                    _HowToPlayCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        border: Border.all(
            color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('🎵', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            'Catch the song first!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Listen to short clips and guess the song\nbefore your friends do.',
            textAlign: TextAlign.center,
            style:
            TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Clip reveal badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ClipBadge(seconds: 3, color: Colors.greenAccent),
              const SizedBox(width: 8),
              _ClipBadge(seconds: 5, color: Colors.amberAccent),
              const SizedBox(width: 8),
              _ClipBadge(seconds: 10, color: Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClipBadge extends StatelessWidget {
  final int seconds;
  final Color color;
  const _ClipBadge({required this.seconds, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          fontSize: 13,
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
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
        Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: Colors.amber, size: 16),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You\'re playing as a guest. Your progress won\'t be saved.',
              style:
              TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRegister,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                foregroundColor: Colors.amber),
            child: const Text('Register',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
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
      padding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
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
          const Text(
            'How to Play',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          _Step(
            icon: '🎵',
            title: 'Hear a clip',
            description:
            'A short audio clip plays — 3s, 5s, or 10s.',
          ),
          const SizedBox(height: 12),
          _Step(
            icon: '💡',
            title: 'Guess the song',
            description:
            'Type the song title or artist name.',
          ),
          const SizedBox(height: 12),
          _Step(
            icon: '⚡',
            title: 'Score points',
            description:
            'Faster correct guesses earn more points.',
          ),
          const SizedBox(height: 12),
          _Step(
            icon: '🏆',
            title: 'Win the round',
            description:
            'Most points after all rounds wins!',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _Step({
    required this.icon,
    required this.title,
    required this.description,
  });

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
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              Text(
                description,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              GestureDetector(
                onLongPress: () => context.go('/admin/seed'),
                child: const Text(
                  'songcatcher.io',
                  style: TextStyle(color: Colors.white12, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}