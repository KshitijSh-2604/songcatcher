import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/game_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _codeController = TextEditingController();
  final _gameService = GameService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

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

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final user = ref.read(currentUserProvider)!;
    setState(() { _loading = true; _error = null; });
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  backgroundColor: Colors.purpleAccent.withOpacity(0.3),
                  child: user.photoURL == null
                      ? Text((user.displayName ?? 'P')[0].toUpperCase())
                      : null,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 18),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) async {
                  if (val == 'logout') {
                    context.go('/login');
                  }
                },
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Text(
                    '🎵',
                    style: const TextStyle(fontSize: 56),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SongCatcher',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Catch the song before anyone else!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Error
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Create Room
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _createRoom,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Room'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purpleAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Join Room
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Room Code (e.g. XK9P2A)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading ? null : _joinRoom,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 20),
                        ),
                        child: _loading
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                            : const Text('Join'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}