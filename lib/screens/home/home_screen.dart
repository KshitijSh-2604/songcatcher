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
  final _codeCtrl = TextEditingController();
  final _gameService = GameService();

  bool _loading = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roomId = await _gameService.createRoom(
        hostId: user.uid,
        hostName: user.displayName ?? 'Host',
        genre: 'Bollywood',
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
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a room code.');
      return;
    }
    if (code.length != 6) {
      setState(() => _error = 'Room code must be 6 characters.');
      return;
    }

    final user = ref.read(currentUserProvider)!;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roomId = await _gameService.joinRoom(
        code: code,
        userId: user.uid,
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
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
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
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (!isGuest && user.email != null)
                          Text(user.email!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  if (isGuest)
                    const PopupMenuItem(
                      value: 'register',
                      child: Row(children: [
                        Icon(Icons.person_add_outlined, size: 18, color: Colors.purpleAccent),
                        SizedBox(width: 10),
                        Text('Create Account', style: TextStyle(color: Colors.purpleAccent)),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth.clamp(320, 1100),
                    ),
                    child: Padding(
                      padding: context.pagePadding,
                      child: context.twoColumn
                          ? _WideHome(
                        isGuest: isGuest,
                        error: _error,
                        loading: _loading,
                        codeCtrl: _codeCtrl,
                        onCreate: _createRoom,
                        onJoin: _joinRoom,
                        onRegister: () => context.go('/login'),
                      )
                          : _NarrowHome(
                        isGuest: isGuest,
                        error: _error,
                        loading: _loading,
                        codeCtrl: _codeCtrl,
                        onCreate: _createRoom,
                        onJoin: _joinRoom,
                        onRegister: () => context.go('/login'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Wide layout — two columns, no scroll ───────────────────────────────────

class _WideHome extends StatelessWidget {
  final bool isGuest;
  final String? error;
  final bool loading;
  final TextEditingController codeCtrl;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onRegister;

  const _WideHome({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(large: true),
              Gap(context.fs(22, max: 32)),
              if (isGuest) ...[
                _GuestBanner(onRegister: onRegister),
                Gap(context.fs(16, max: 22)),
              ],
              if (error != null) ...[
                _ErrorBanner(message: error!),
                Gap(context.fs(12, max: 18)),
              ],
              FilledButton.icon(
                onPressed: loading ? null : onCreate,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Room'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: EdgeInsets.symmetric(vertical: context.fs(15, max: 20)),
                  textStyle: TextStyle(fontSize: context.ff(14, max: 17), fontWeight: FontWeight.bold),
                ),
              ),
              Gap(context.fs(16, max: 22)),
              Text('Join a Room',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white70, fontSize: context.ff(12, max: 15))),
              Gap(context.fs(8, max: 12)),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    onSubmitted: (_) => onJoin(),
                    style: TextStyle(fontSize: context.ff(14, max: 18)),
                    decoration: const InputDecoration(
                      hintText: 'Room Code — e.g. XK9P2A',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                      counterText: '',
                    ),
                  ),
                ),
                SizedBox(width: context.fs(10, max: 14)),
                FilledButton(
                  onPressed: loading ? null : onJoin,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                        vertical: context.fs(17, max: 22), horizontal: context.fs(22, max: 30)),
                  ),
                  child: loading
                      ? SizedBox(
                    width: context.ff(16, max: 20),
                    height: context.ff(16, max: 20),
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Text('Join', style: TextStyle(fontSize: context.ff(14, max: 18))),
                ),
              ]),
            ],
          ),
        ),
        SizedBox(width: context.fs(32, max: 48)),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _HowToPlayCard(),
              Gap(context.fs(16, max: 22)),
              const _DifficultyGuide(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Narrow layout — single column, no scroll (scales down instead) ────────

class _NarrowHome extends StatelessWidget {
  final bool isGuest;
  final String? error;
  final bool loading;
  final TextEditingController codeCtrl;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onRegister;

  const _NarrowHome({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(context.fs(6, max: 10)),
        _HeroCard(large: context.isTablet),
        Gap(context.fs(20, max: 28)),
        if (isGuest) ...[
          _GuestBanner(onRegister: onRegister),
          Gap(context.fs(12, max: 18)),
        ],
        if (error != null) ...[
          _ErrorBanner(message: error!),
          Gap(context.fs(10, max: 14)),
        ],
        FilledButton.icon(
          onPressed: loading ? null : onCreate,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Create Room'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.purpleAccent,
            padding: EdgeInsets.symmetric(vertical: context.fs(13, max: 18)),
          ),
        ),
        Gap(context.fs(14, max: 20)),
        Text('Join a Room',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.white70, fontSize: context.ff(11, max: 14))),
        Gap(context.fs(6, max: 10)),
        Row(children: [
          Expanded(
            child: TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              onSubmitted: (_) => onJoin(),
              style: TextStyle(fontSize: context.ff(13, max: 16)),
              decoration: const InputDecoration(
                hintText: 'Room Code — e.g. XK9P2A',
                prefixIcon: Icon(Icons.meeting_room_outlined),
                counterText: '',
              ),
            ),
          ),
          SizedBox(width: context.fs(8, max: 12)),
          FilledButton(
            onPressed: loading ? null : onJoin,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                  vertical: context.fs(15, max: 20), horizontal: context.fs(18, max: 24)),
            ),
            child: loading
                ? SizedBox(
              width: context.ff(16, max: 20),
              height: context.ff(16, max: 20),
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : Text('Join', style: TextStyle(fontSize: context.ff(13, max: 16))),
          ),
        ]),
        Gap(context.fs(22, max: 30)),
        const _HowToPlayCard(),
        Gap(context.fs(14, max: 20)),
        const _DifficultyGuide(),
        Gap(context.fs(12, max: 18)),
      ],
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
      padding: EdgeInsets.all(context.fs(large ? 26 : 20, max: large ? 38 : 30)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purpleAccent.withOpacity(0.2), Colors.deepPurple.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('🎵', style: TextStyle(fontSize: context.ff(large ? 46 : 38, max: large ? 62 : 50))),
          Gap(context.fs(large ? 12 : 9, max: large ? 16 : 12)),
          Text(
            'Catch the song first!',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: context.ff(large ? 22 : 18, max: large ? 30 : 24),
            ),
            textAlign: TextAlign.center,
          ),
          Gap(context.fs(7, max: 10)),
          Text(
            'Listen to short clips and guess the song\nbefore your friends do.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: context.ff(large ? 13 : 12, max: large ? 17 : 15)),
          ),
          Gap(context.fs(large ? 18 : 14, max: large ? 24 : 20)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ClipBadge(seconds: 2, color: Colors.tealAccent, large: large),
              SizedBox(width: context.fs(6, max: 9)),
              _ClipBadge(seconds: 3, color: Colors.greenAccent, large: large),
              SizedBox(width: context.fs(6, max: 9)),
              _ClipBadge(seconds: 5, color: Colors.amberAccent, large: large),
              SizedBox(width: context.fs(6, max: 9)),
              _ClipBadge(seconds: 10, color: Colors.redAccent, large: large),
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
  final bool large;
  const _ClipBadge({required this.seconds, required this.color, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(large ? 13 : 10, max: large ? 18 : 14),
          vertical: context.fs(large ? 6 : 5, max: large ? 9 : 7)),
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
          fontSize: context.ff(large ? 13 : 11, max: large ? 17 : 15),
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
      padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 16), vertical: context.fs(10, max: 14)),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: Colors.amber, size: context.ff(14, max: 18)),
        SizedBox(width: context.fs(8, max: 12)),
        Expanded(
          child: Text(
            'You\'re playing as a guest. Your progress won\'t be saved.',
            style: TextStyle(color: Colors.amber, fontSize: context.ff(11, max: 13)),
          ),
        ),
        TextButton(
          onPressed: onRegister,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, foregroundColor: Colors.amber),
          child: Text('Register', style: TextStyle(fontSize: context.ff(11, max: 13))),
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
      padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 16), vertical: context.fs(9, max: 12)),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Colors.redAccent, size: context.ff(14, max: 18)),
        SizedBox(width: context.fs(7, max: 10)),
        Expanded(
          child: Text(message, style: TextStyle(color: Colors.redAccent, fontSize: context.ff(12, max: 14))),
        ),
      ]),
    );
  }
}

// ── How to Play Card ───────────────────────────────────────────────────────

class _HowToPlayCard extends StatelessWidget {
  const _HowToPlayCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.fs(16, max: 22)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.ff(13, max: 17))),
          Gap(context.fs(12, max: 16)),
          _Step(icon: '🎵', title: 'Hear a clip', desc: 'A short audio clip plays — 2s, 3s, 5s, or 10s.'),
          Gap(context.fs(9, max: 12)),
          _Step(icon: '💡', title: 'Guess the song', desc: 'Type the song title or artist name.'),
          Gap(context.fs(9, max: 12)),
          _Step(icon: '⚡', title: 'Score points', desc: 'Faster correct guesses earn more points.'),
          Gap(context.fs(9, max: 12)),
          _Step(icon: '🏆', title: 'Win the round', desc: 'Most points after all rounds wins!'),
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
        Text(icon, style: TextStyle(fontSize: context.ff(17, max: 22))),
        SizedBox(width: context.fs(10, max: 14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.ff(12, max: 15))),
              Text(desc, style: TextStyle(color: Colors.white54, fontSize: context.ff(11, max: 13))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Difficulty Guide ───────────────────────────────────────────────────────

class _DifficultyGuide extends StatelessWidget {
  const _DifficultyGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.fs(13, max: 18)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Difficulty Levels',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: context.ff(12, max: 15), color: Colors.white70)),
          Gap(context.fs(8, max: 12)),
          _DiffRow(emoji: '🟢', label: 'Easy', desc: 'Chart-toppers everyone knows'),
          _DiffRow(emoji: '🟡', label: 'Medium', desc: 'Popular but not mega-hits'),
          _DiffRow(emoji: '🔴', label: 'Hard', desc: 'Less mainstream tracks'),
          _DiffRow(emoji: '💀', label: 'Hardcore', desc: 'Deep cuts & obscure songs'),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String desc;
  const _DiffRow({required this.emoji, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.fs(5, max: 8)),
      child: Row(children: [
        Text(emoji, style: TextStyle(fontSize: context.ff(12, max: 15))),
        SizedBox(width: context.fs(6, max: 9)),
        Text('$label  ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.ff(11, max: 14))),
        Expanded(
          child: Text(desc, style: TextStyle(color: Colors.white38, fontSize: context.ff(10, max: 12))),
        ),
      ]),
    );
  }
}