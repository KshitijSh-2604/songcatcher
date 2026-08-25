import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';
import '../../models/app_user.dart';
import '../../services/user_service.dart';
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
  int _startCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Record current room ID for sidebar persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentRoomIdProvider.notifier).state = widget.roomId;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      // 🚨 Host sets synced countdown to 5
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
        content: Text('Are you sure you want to kick $name? They will be permanently banned from joining this specific lobby ever again.'),
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

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user = ref.watch(currentUserProvider);

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          // If room deleted (last person left), redirect home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_navigating) {
              _navigating = true;
              context.go('/home');
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (room.status == RoomStatus.playing && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        // 🚨 Kick logic: If user is no longer in players list, boot them
        final players = playersAsync.valueOrNull ?? [];
        final isStillInRoom = players.any((p) => p.id == user?.uid);
        if (!isStillInRoom && players.isNotEmpty && !_navigating) {
           _navigating = true;
           WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentRoomIdProvider.notifier).state = null;
              context.go('/home');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have been kicked from the lobby.'), backgroundColor: Colors.red),
              );
           });
        }

        final isHost = user?.uid == room.hostId;

        return Stack(
          children: [
            PageShell(
              showHeader: true,
              showSidebar: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NeubrutalistButton(
                        label: '← LEAVE ARENA',
                        color: Colors.white,
                        onPressed: () async {
                          ref.read(currentRoomIdProvider.notifier).state = null;
                          await _gameService.leaveRoom(widget.roomId, user!.uid);
                          if (mounted) context.go('/home');
                        },
                      ),
                    ],
                  ),
                  const Gap(24),
                  NeubrutalistContainer(
                    color: const Color(0xFFFFFF00),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('Match Lobby', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)),
                        const SizedBox(height: 8),
                        const Text('Configure your settings and wait for the beat to drop.', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Room Code: ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black)),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _copyCode(room.code),
                                child: NeubrutalistContainer(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  color: Colors.white,
                                  shadowOffset: 2,
                                  child: Text(room.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2, color: Color(0xFF0001BB))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
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
                                color: const Color(0xFF00FF00),
                                onPressed: (players.length >= 1 && !_starting) ? _startGame : null,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: playersAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (players) => _PlayersList(
                            players: players, 
                            user: user, 
                            room: room, 
                            roomId: widget.roomId,
                            onKick: isHost ? _onKick : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 🚨 Start Game Countdown Overlay
            if ((room.startCountdown) > 0)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('ARENA STARTING', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
                        const Gap(20),
                        Text('${room.startCountdown}', 
                           style: const TextStyle(color: Color(0xFF00FF00), fontSize: 120, fontWeight: FontWeight.w900))
                           .animate(key: ValueKey(room.startCountdown)).scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),
                      ],
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

  const _PlayersList({required this.players, required this.user, required this.room, required this.roomId, this.onKick});

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
        )),
        if (players.length < 8)
          NeubrutalistContainer(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0xFFEEEEEE),
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
  const _PlayerEntry({required this.player, required this.isMe, required this.isHost, this.onKick});

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
        transform: _hovering ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
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
              Expanded(child: Text(widget.player.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
              if (widget.isHost) const Icon(Icons.star, color: Color(0xFFFFFF00), size: 18),
              if (widget.isMe) Text(' (YOU)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Theme.of(context).primaryColor)),
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
  const _HostControls({required this.room, required this.roomId, required this.gameService, required this.playerCount, required this.starting, required this.onStart});

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
    _yearRange = RangeValues(widget.room.yearFrom.toDouble(), widget.room.yearTo.toDouble().clamp(1950, 2024));
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
        Row(
          children: [
            _VibeChip(label: 'Bollywood', selected: _selectedVibes.contains('Bollywood'), onTap: () => _toggleVibe('Bollywood')),
            const SizedBox(width: 8),
            _VibeChip(label: 'English', selected: _selectedVibes.contains('English'), onTap: () => _toggleVibe('English')),
            const SizedBox(width: 8),
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
          values: _yearRange, min: 1950, max: 2020, divisions: 7,
          labels: RangeLabels(_yearRange.start.round().toString(), _yearRange.end.round().toString()),
          onChanged: (v) {
            // Ensure at least 10 years gap (1 division) and no overlap
            if (v.end - v.start < 10) {
               if (v.start != _yearRange.start) {
                  // User moving start slider -> push end slider
                  setState(() => _yearRange = RangeValues(v.start, (v.start + 10).clamp(1950, 2020)));
               } else {
                  // User moving end slider -> push start slider back
                  setState(() => _yearRange = RangeValues((v.end - 10).clamp(1950, 2020), v.end));
               }
            } else {
               setState(() => _yearRange = v);
            }
          },
          onChangeEnd: (v) => widget.gameService.updateRoomSettings(widget.roomId, yearRangeStart: v.start.round(), yearRangeEnd: v.end.round()),
        ),
        const Gap(12),
        Text('Room Visibility', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const Gap(8),
        Row(
          children: [
            _VisibilityToggle(
              isPublic: widget.room.isPublic,
              onChanged: (val) {
                widget.gameService.updateRoomSettings(widget.roomId, isPublic: val);
              },
            ),
          ],
        ),
      ],
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
            // Custom switch look
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
