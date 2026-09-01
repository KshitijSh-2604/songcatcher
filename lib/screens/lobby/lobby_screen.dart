import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';
import '../../models/app_user.dart';
import '../../models/friendship.dart';
import '../../services/friend_service.dart';
import '../game/widgets/skribbl_avatar.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _gameService = GameService();
  bool _starting = false;
  bool _navigating = false;
  bool _joining = true; // 🆕 Track joining state
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _handleInitialJoin();
  }

  Future<void> _handleInitialJoin() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(currentRoomIdProvider.notifier).state = widget.roomId;
      
      final user = ref.read(currentUserProvider);
      // Wait for profile if it's still loading
      final profile = await ref.read(userProfileProvider.future);
      
      if (user != null) {
        // 🚀 Update activity status
        ref.read(userServiceProvider).updateActivity(user.uid, 'In Lobby');

        try {
          // Check if already in players list
          final players = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('players')
              .get();
          
          final amIIn = players.docs.any((d) => d.id == user.uid);
          
          if (!amIIn) {
            await _gameService.joinRoomById(
              roomId: widget.roomId,
              userId: user.uid,
              displayName: profile?.displayName ?? user.displayName ?? 'Player',
              photoUrl: profile?.photoUrl,
              avatarConfig: profile?.avatarConfig ?? {},
            );
          }
        } catch (e) {
          debugPrint('Error joining room: $e');
          if (mounted) context.go('/home');
        }
      }
      
      if (mounted) setState(() => _joining = false);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_starting) return;
    
    // 👑 Only the host should manage the countdown and start logic
    final room = ref.read(roomProvider(widget.roomId)).valueOrNull;
    final user = ref.read(currentUserProvider);
    if (room?.hostId != user?.uid) return;

    setState(() => _starting = true);
    try {
      await _gameService.updateStartCountdown(widget.roomId, 5);
      
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        final current = ref.read(roomProvider(widget.roomId)).valueOrNull?.startCountdown ?? 0;
        
        if (current > 1) {
          await _gameService.updateStartCountdown(widget.roomId, current - 1);
        } else {
          timer.cancel();
          await _gameService.updateStartCountdown(widget.roomId, 0);
          await _gameService.startGame(widget.roomId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
        setState(() => _starting = false);
      }
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied!'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _onKick(String playerId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kick Player?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to kick $name? They will be permanently banned from joining this lobby.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('KICK & BAN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _gameService.kickPlayer(widget.roomId, playerId);
    }
  }

  void _showInviteDialog(BuildContext context, String roomCode) {
    showDialog(
      context: context,
      builder: (ctx) => _InviteFriendsDialog(
        roomId: widget.roomId,
        roomCode: roomCode,
      ),
    );
  }

  Future<void> _onRename() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    
    final players = ref.read(playersProvider(widget.roomId)).valueOrNull ?? [];
    final me = players.firstWhere((p) => p.id == user.uid);
    final ctrl = TextEditingController(text: me.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Display Name', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will change your name for this session.'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 15,
              decoration: const InputDecoration(hintText: 'Enter new name...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      try {
        await _gameService.updatePlayerDisplayName(widget.roomId, user.uid, newName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomStatus = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.status));
    final startCountdown = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.startCountdown ?? 0));
    final roomCode = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.code ?? ''));
    final hostId = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.hostId));
    final isPartyMode = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.isPartyMode ?? false));
    final isPublic = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.isPublic ?? false));
    final forceLockVisibility = ref.watch(roomProvider(widget.roomId).select((r) => r.value?.forceLockVisibility ?? false));

    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

    return ref.watch(roomProvider(widget.roomId)).when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          if (_joining) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_navigating) {
              _navigating = true;
              context.go('/home');
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (roomStatus == RoomStatus.playing && !_navigating) {
          _navigating = true;
          // 🚀 Add a high-energy zoom transition effect before leaving
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        final players = playersAsync.valueOrNull ?? [];
        final isStillInRoom = players.any((p) => p.id == user?.uid);
        if (!isStillInRoom && players.isNotEmpty && !_navigating && !_joining) {
           _navigating = true;
           WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentRoomIdProvider.notifier).state = null;
              context.go('/home');
           });
        }

        final isHost = user?.uid == hostId;

        return Stack(
          children: [
            PageShell(
              showHeader: true,
              showSidebar: true,
              scrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NeubrutalistButton(
                        label: context.isMobile ? '←' : '← LEAVE ARENA',
                        color: Colors.white,
                        onPressed: () async {
                          final goRouter = GoRouter.of(context);
                          ref.read(currentRoomIdProvider.notifier).state = null;
                          if (user != null) {
                             await _gameService.leaveRoom(widget.roomId, user.uid);
                          }
                          if (mounted) goRouter.go('/home');
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: NeubrutalistButton(
                          label: context.isMobile ? 'INVITE ✉️' : 'INVITE FRIENDS ✉️',
                          color: const Color(0xFF00FF00),
                          onPressed: () => _showInviteDialog(context, roomCode),
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),
                  NeubrutalistContainer(
                    color: const Color(0xFFFFFF00),
                    padding: EdgeInsets.all(context.fs(16, max: 40)),
                    child: Column(
                      children: [
                        Text('Match Lobby', style: GoogleFonts.bricolageGrotesque(fontSize: context.ff(24, max: 42), fontWeight: FontWeight.w900, color: Colors.black)),
                        if (isPartyMode) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PARTY MODE 🥳', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                        ],
                        const Gap(8),
                        Text('Configure match and wait for the drop.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: context.ff(12, max: 16), color: Colors.black54)),
                        Gap(context.fs(12, max: 24)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Room Code: ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: context.ff(14, max: 20), color: Colors.black)),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _copyCode(roomCode),
                                child: NeubrutalistContainer(
                                  padding: EdgeInsets.symmetric(horizontal: context.fs(12, max: 20), vertical: context.fs(4, max: 8)),
                                  color: Colors.white,
                                  shadowOffset: 2,
                                  child: Text(roomCode, style: TextStyle(fontWeight: FontWeight.w900, fontSize: context.ff(18, max: 32), letterSpacing: 2, color: const Color(0xFF0001BB))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),

                  AdaptiveRow(
                    collapseBelow: 1000,
                    children: [
                      Column(
                        children: [
                          NeubrutalistContainer(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.settings, color: Theme.of(context).textTheme.bodyLarge?.color),
                                    const SizedBox(width: 12),
                                    const Text('Match Settings', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                  ],
                                ),
                                const Gap(24),
                                if (isHost)
                                  _HostControls(
                                    room: room,
                                    roomId: widget.roomId,
                                    gameService: _gameService,
                                    playerCount: players.length,
                                    starting: _starting,
                                    onStart: _startGame,
                                    isPartyMode: isPartyMode,
                                    isPublic: isPublic,
                                    forceLockVisibility: forceLockVisibility,
                                  )
                                else
                                  const _GuestWaitingView(),
                              ],
                            ),
                          ),
                          const Gap(24),
                          if (isHost)
                            NeubrutalistButton(
                              label: _starting ? 'STARTING...' : 'START MATCH',
                              color: (players.where((p) => p.id != user?.uid).every((p) => p.isReady)) 
                                  ? const Color(0xFF00FF00) 
                                  : Colors.grey,
                              onPressed: (players.isNotEmpty && !_starting && players.where((p) => p.id != user?.uid).every((p) => p.isReady)) 
                                  ? _startGame : null,
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .scale(end: const Offset(1.05, 1.05), duration: 800.ms, curve: Curves.easeInOut)
                          else
                            NeubrutalistButton(
                              label: players.firstWhere((p) => p.id == user?.uid, orElse: () => players.first).isReady 
                                  ? 'READY! ✅' 
                                  : 'I\'M READY ✋',
                              color: players.firstWhere((p) => p.id == user?.uid, orElse: () => players.first).isReady 
                                  ? const Color(0xFF00FF00) 
                                  : const Color(0xFFFFFF00),
                              onPressed: () => _gameService.updateReadyStatus(widget.roomId, user!.uid, !players.firstWhere((p) => p.id == user?.uid).isReady),
                            ),
                        ],
                      ),
                      playersAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (players) => _PlayersList(
                          players: players, 
                          user: user, 
                          room: room, 
                          roomId: widget.roomId,
                          onKick: isHost ? _onKick : null,
                          onRename: _onRename,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (startCountdown > 0)
              Positioned.fill(
                child: RepaintBoundary(
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.85),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PREPARING ARENA', 
                              style: GoogleFonts.bricolageGrotesque(
                                color: Colors.white, 
                                fontSize: context.ff(20, max: 32), 
                                fontWeight: FontWeight.w900, 
                                letterSpacing: 8
                              ),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                            const Gap(40),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: context.fs(180, max: 240),
                                  height: context.fs(180, max: 240),
                                  child: CircularProgressIndicator(
                                    value: startCountdown / 5,
                                    strokeWidth: 12,
                                    color: const Color(0xFF00FF00),
                                    backgroundColor: Colors.white10,
                                  ),
                                ),
                                Text(
                                  '$startCountdown', 
                                  style: GoogleFonts.bricolageGrotesque(
                                    color: const Color(0xFF00FF00), 
                                    fontSize: context.ff(80, max: 120), 
                                    fontWeight: FontWeight.w900
                                  )
                                ).animate(key: ValueKey(startCountdown)).scale(begin: const Offset(0.4, 0.4), curve: Curves.elasticOut),
                              ],
                            ),
                            const Gap(40),
                            const Text(
                              'GET READY TO CATCH THE BEAT...',
                              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlayersList extends StatelessWidget {
  final List players;
  final dynamic user;
  final Room room;
  final String roomId;
  final Function(String, String)? onKick;
  final VoidCallback onRename;

  const _PlayersList({required this.players, required this.user, required this.room, required this.roomId, this.onKick, required this.onRename});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeubrutalistContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.people, color: Theme.of(context).textTheme.bodyLarge?.color),
              const SizedBox(width: 8),
              Text('Players (${players.length}/8)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ),
        const Gap(12),
        ...players.map((p) => _PlayerEntry(
          player: p, 
          isMe: p.id == user?.uid, 
          isHost: p.id == room.hostId,
          onKick: (p.id != user?.uid && onKick != null) ? () => onKick!(p.id, p.displayName) : null,
          onRename: p.id == user?.uid ? onRename : null,
        )),
        if (players.length < 8)
          NeubrutalistContainer(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFEEEEEE),
            padding: const EdgeInsets.all(12),
            shadowOffset: 0,
            child: Row(
              children: [
                Icon(Icons.person_add_outlined, color: Theme.of(context).hintColor),
                const SizedBox(width: 12),
                Text('Waiting for players...', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlayerEntry extends StatefulWidget {
  final dynamic player;
  final bool isMe;
  final bool isHost;
  final VoidCallback? onKick;
  final VoidCallback? onRename;
  const _PlayerEntry({required this.player, required this.isMe, required this.isHost, this.onKick, this.onRename});

  @override
  State<_PlayerEntry> createState() => _PlayerEntryState();
}

class _PlayerEntryState extends State<_PlayerEntry> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        transform: _hovering ? Matrix4.diagonal3Values(1.02, 1.02, 1.0) : Matrix4.identity(),
        child: NeubrutalistContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shadowOffset: _hovering ? 6 : 2,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                child: Center(child: SkribblAvatar(config: AvatarConfig.fromMap(widget.player.avatarConfig), size: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(widget.player.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis)),
                    if (!widget.isHost) ...[
                      const SizedBox(width: 8),
                      if (widget.player.isReady)
                        const Icon(Icons.check_circle, color: Colors.green, size: 16)
                      else
                        Text('WAITING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.red.withOpacity(0.5))),
                    ],
                  ],
                ),
              ),
              if (widget.isHost) const Icon(Icons.star, color: Color(0xFFFFFF00), size: 18),
              if (widget.isMe) ...[
                Text(' (YOU)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Theme.of(context).primaryColor)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: widget.onRename,
                  tooltip: 'Change Name',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              if (widget.onKick != null)
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 18),
                  onPressed: widget.onKick,
                  tooltip: 'Kick Player',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestWaitingView extends StatelessWidget {
  const _GuestWaitingView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 20), Text('Waiting for host to start...', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54))]));
  }
}

class _HostControls extends StatefulWidget {
  final Room room;
  final String roomId;
  final GameService gameService;
  final int playerCount;
  final bool starting;
  final VoidCallback onStart;
  final bool isPartyMode;
  final bool isPublic;
  final bool forceLockVisibility;

  const _HostControls({required this.room, required this.roomId, required this.gameService, required this.playerCount, required this.starting, required this.onStart, required this.isPartyMode, required this.isPublic, required this.forceLockVisibility});

  @override
  State<_HostControls> createState() => _HostControlsState();
}

class _HostControlsState extends State<_HostControls> {
  late RangeValues _yearRange;
  late int _songCount;
  late List<String> _selectedVibes;
  late List<int> _selectedStages;

  @override
  void initState() {
    super.initState();
    _yearRange = RangeValues(
      widget.room.yearFrom.toDouble(), 
      widget.room.yearTo.toDouble() > 2020 ? 2030 : widget.room.yearTo.toDouble()
    );
    _songCount = widget.room.totalRounds;
    _selectedVibes = List<String>.from(widget.room.selectedVibes);
    _selectedStages = List<int>.from(widget.room.selectedClipStages);
  }

  void _toggleVibe(String vibe) {
    setState(() {
      if (_selectedVibes.contains(vibe)) {
        if (_selectedVibes.length > 1) _selectedVibes.remove(vibe);
      } else {
        _selectedVibes.add(vibe);
      }
    });
    widget.gameService.updateRoomSettings(widget.roomId, selectedVibes: _selectedVibes);
  }

  void _toggleStage(int s) {
    setState(() {
      if (_selectedStages.contains(s)) {
        _selectedStages.remove(s);
      } else {
        _selectedStages.add(s);
        _selectedStages.sort((a, b) => a.compareTo(b));
      }
    });
    widget.gameService.updateRoomSettings(widget.roomId, selectedClipStages: _selectedStages);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Select Vibes (Pick 1+)', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _VibeChip(label: 'Bollywood', selected: _selectedVibes.contains('Bollywood'), onTap: () => _toggleVibe('Bollywood')),
            _VibeChip(label: 'Punjabi', selected: _selectedVibes.contains('Punjabi'), onTap: () => _toggleVibe('Punjabi')),
            _VibeChip(label: 'English', selected: _selectedVibes.contains('English'), onTap: () => _toggleVibe('English')),
            _VibeChip(label: 'International', selected: _selectedVibes.contains('International'), onTap: () => _toggleVibe('International')),
          ],
        ),
        const Gap(24),
        Text('Clip Lengths (2s, 3s, 5s mandatory)', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const Gap(8),
        Wrap(
          spacing: 8,
          children: [
            const _StageChip(label: '2s', selected: true, mandatory: true),
            const _StageChip(label: '3s', selected: true, mandatory: true),
            const _StageChip(label: '5s', selected: true, mandatory: true),
            _StageChip(label: '8s', selected: _selectedStages.contains(8), onTap: () => _toggleStage(8)),
            _StageChip(label: '10s', selected: _selectedStages.contains(10), onTap: () => _toggleStage(10)),
          ],
        ),
        const Gap(24),
        Text('Songs: $_songCount', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
        Slider(
          value: _songCount.toDouble(),
          min: 5, max: 25, divisions: 20,
          onChanged: (v) => setState(() => _songCount = v.round()),
          onChangeEnd: (v) => widget.gameService.updateRoomSettings(widget.roomId, totalRounds: v.round()),
        ),
        const Gap(12),
        Text('Song Era', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
        RangeSlider(
          values: _yearRange, min: 1950, max: 2030, divisions: 8,
          labels: RangeLabels(
            _yearRange.start >= 2030 ? 'Now' : _yearRange.start.round().toString(), 
            _yearRange.end >= 2030 ? 'Now' : _yearRange.end.round().toString()
          ),
          onChanged: (v) {
            if (v.end - v.start < 10) {
               if (v.start != _yearRange.start) {
                  setState(() => _yearRange = RangeValues(v.start, (v.start + 10).clamp(1950, 2030)));
               } else {
                  setState(() => _yearRange = RangeValues((v.end - 10).clamp(1950, 2030), v.end));
               }
            } else {
               setState(() => _yearRange = v);
            }
          },
          onChangeEnd: (v) => widget.gameService.updateRoomSettings(widget.roomId, yearRangeStart: v.start.round(), yearRangeEnd: v.end.round()),
        ),
        if (!widget.isPartyMode && !widget.forceLockVisibility) ...[
          const Gap(12),
          Text('Room Visibility', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const Gap(8),
          Row(
            children: [
              _VisibilityToggle(
                isPublic: widget.isPublic,
                onChanged: (val) {
                  widget.gameService.updateRoomSettings(widget.roomId, isPublic: val);
                },
              ),
            ],
          ),
        ],
        if (widget.forceLockVisibility) ...[
          const Gap(12),
          Text('Room Visibility', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const Gap(8),
          Row(
            children: [
              NeubrutalistContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF00FF00),
                shadowOffset: 0,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.public, color: Colors.black, size: 20),
                    SizedBox(width: 12),
                    Text('PUBLIC ARENA (LOCKED)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InviteFriendsDialog extends ConsumerWidget {
  final String roomId;
  final String roomCode;
  const _InviteFriendsDialog({required this.roomId, required this.roomCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    // 🚀 FIX: Use friendshipsProvider to get IDs and userStreamProvider to get FRESH profiles
    final friendshipsAsync = ref.watch(friendshipsProvider(user.uid));

    return AlertDialog(
      title: const Text('Invite Friends', style: TextStyle(fontWeight: FontWeight.w900)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: friendshipsAsync.when(
          data: (friendships) {
            if (friendships.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No friends found to invite.', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 20),
                  NeubrutalistButton(
                    label: 'ADD FRIENDS',
                    color: const Color(0xFFFFFF00),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/friends');
                    },
                  ),
                ],
              );
            }

            return SizedBox(
              width: 400,
              height: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friendships.length,
                itemBuilder: (context, index) {
                  final otherId = friendships[index].getOtherId(user.uid);
                  return _FreshInviteTile(
                    userId: otherId,
                    roomId: roomId,
                    roomCode: roomCode,
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('DONE')),
      ],
    );
  }
}

class _FreshInviteTile extends ConsumerStatefulWidget {
  final String userId;
  final String roomId;
  final String roomCode;
  const _FreshInviteTile({required this.userId, required this.roomId, required this.roomCode});

  @override
  ConsumerState<_FreshInviteTile> createState() => _FreshInviteTileState();
}

class _FreshInviteTileState extends ConsumerState<_FreshInviteTile> {
  bool _invited = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider(widget.userId));

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: NeubrutalistContainer(
            padding: const EdgeInsets.all(8),
            shadowOffset: 2,
            child: Row(
              children: [
                SkribblAvatar(config: AvatarConfig.fromMap(user.avatarConfig), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        user.isOnline ? '🟢 ${user.currentActivity}' : '⚪ OFFLINE', 
                        style: TextStyle(fontSize: 9, color: user.isOnline ? Colors.green : Colors.black26, fontWeight: FontWeight.w900)
                      ),
                    ],
                  ),
                ),
                _invited
                    ? const Icon(Icons.check, color: Colors.green)
                    : IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF4D4DFF)),
                        onPressed: () async {
                          try {
                            final me = ref.read(userProfileProvider).valueOrNull;
                            if (me == null) return;
                            
                            await ref.read(friendServiceProvider).sendLobbyInvite(
                              fromUid: me.uid,
                              fromName: me.displayName,
                              toUid: user.uid,
                              roomId: widget.roomId,
                              roomCode: widget.roomCode,
                            );
                            if (mounted) setState(() => _invited = true);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to invite: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const _VisibilityToggle({required this.isPublic, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isPublic),
      child: NeubrutalistContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isPublic ? const Color(0xFF00FF00) : const Color(0xFF720100),
        shadowOffset: 2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPublic ? Icons.public : Icons.lock, 
                 color: isPublic ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              isPublic ? 'PUBLIC ARENA' : 'PRIVATE (CODE ONLY)',
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                fontSize: 12, 
                color: isPublic ? Colors.black : Colors.white
              ),
            ),
            const SizedBox(width: 12),
            NeubrutalistContainer(
              width: 40,
              height: 24,
              padding: EdgeInsets.zero,
              borderRadius: 12,
              color: Colors.white,
              shadowOffset: 0,
              borderWidth: 2,
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: isPublic ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
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

class _VibeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _VibeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: NeubrutalistContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: selected ? const Color(0xFF00FF00) : Colors.white,
        shadowOffset: selected ? 0 : 2,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool mandatory;
  final VoidCallback? onTap;
  const _StageChip({required this.label, required this.selected, this.mandatory = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: mandatory ? null : onTap,
      child: NeubrutalistContainer(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        color: selected ? (mandatory ? const Color(0xFFEEEEEE) : const Color(0xFF0001BB)) : Colors.white,
        shadowOffset: selected ? 0 : 2,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: selected && !mandatory ? Colors.white : Colors.black)),
      ),
    );
  }
}
