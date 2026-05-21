import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/game_service.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final _gameService = GameService();
  bool _starting = false;
  bool _navigating = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    setState(() => _starting = true);
    try {
      await _gameService.startGame(widget.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room code copied!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Room?'),
        content: const Text(
            'Are you sure you want to leave this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

    return roomAsync.when(
      loading: () =>
      const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          return const Scaffold(
              body: Center(child: Text('Room not found.')));
        }

        // Navigate to game when host starts
        if (room.status == RoomStatus.playing && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        final isHost = user?.uid == room.hostId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lobby'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _leaveRoom,
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ── Room code card ──────────────────────────────
                      _RoomCodeCard(
                        code: room.code,
                        onCopy: () => _copyCode(room.code),
                      ),
                      const SizedBox(height: 20),

                      // ── Players section ─────────────────────────────
                      Expanded(
                        child: playersAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (e, _) =>
                              Center(child: Text('$e')),
                          data: (players) => Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  const Icon(Icons.people,
                                      size: 18,
                                      color: Colors.white54),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Players (${players.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (players.length < 2)
                                    const Text(
                                      'Need at least 2',
                                      style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Player list
                              Expanded(
                                child: ListView.separated(
                                  itemCount: players.length,
                                  separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final p = players[i];
                                    final isMe =
                                        p.id == user?.uid;
                                    final isRoomHost =
                                        p.id == room.hostId;

                                    return _PlayerTile(
                                      displayName: p.displayName,
                                      isMe: isMe,
                                      isHost: isRoomHost,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Bottom actions ──────────────────────────────
                      if (isHost)
                        _HostControls(
                          playerCount: playersAsync.valueOrNull?.length ?? 0,
                          starting: _starting,
                          onStart: _startGame,
                        )
                      else
                        _WaitingIndicator(pulseAnim: _pulseAnim),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Room Code Card ─────────────────────────────────────────────────────────

class _RoomCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _RoomCodeCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purpleAccent.withOpacity(0.2),
            Colors.deepPurple.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
        Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'Room Code',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),

          // Code with letter spacing
          Text(
            code,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: Colors.purpleAccent,
            ),
          ),
          const SizedBox(height: 14),

          // Copy + share row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Share this code with friends to join',
            style:
            TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Player Tile ────────────────────────────────────────────────────────────

class _PlayerTile extends StatelessWidget {
  final String displayName;
  final bool isMe;
  final bool isHost;

  const _PlayerTile({
    required this.displayName,
    required this.isMe,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.purpleAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? Colors.purpleAccent.withOpacity(0.5)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: isHost
                ? Colors.amber.withOpacity(0.2)
                : Colors.purpleAccent.withOpacity(0.2),
            child: Text(
              displayName[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                isHost ? Colors.amber : Colors.purpleAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              displayName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Badges
          Row(
            children: [
              if (isHost)
                _Badge(label: 'Host', color: Colors.amber),
              if (isMe) ...[
                const SizedBox(width: 6),
                _Badge(label: 'You', color: Colors.purpleAccent),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Host Controls ──────────────────────────────────────────────────────────

class _HostControls extends StatelessWidget {
  final int playerCount;
  final bool starting;
  final VoidCallback onStart;

  const _HostControls({
    required this.playerCount,
    required this.starting,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = playerCount >= 2;

    return Column(
      children: [
        if (!canStart)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Waiting for at least 1 more player to join...',
              style:
              TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
            (starting || !canStart) ? null : onStart,
            icon: starting
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              starting ? 'Starting...' : 'Start Game',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: canStart
                  ? Colors.purpleAccent
                  : Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Waiting Indicator (non-host players) ───────────────────────────────────

class _WaitingIndicator extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _WaitingIndicator({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.purpleAccent,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Waiting for host to start the game...',
              style:
              TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}