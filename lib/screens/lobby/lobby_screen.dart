import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/game_service.dart';
import '../../utils/responsive.dart';

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
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied!'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _leaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Room?'),
        content: const Text('Are you sure you want to leave this room?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync    = ref.watch(roomProvider(widget.roomId));
    final playersAsync = ref.watch(playersProvider(widget.roomId));
    final user         = ref.watch(currentUserProvider);

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (room) {
        if (room == null) {
          return const Scaffold(body: Center(child: Text('Room not found.')));
        }

        if (room.status == RoomStatus.playing && !_navigating) {
          _navigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        final isHost = user?.uid == room.hostId;

        return Scaffold(
          appBar: AppBar(
            title: Text('Lobby', style: TextStyle(fontSize: context.ff(16, max: 20))),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _leaveRoom),
          ),
          body: SafeArea(
            child: PageShell(
              scrollable: true,
              maxWidth: context.twoColumn ? 1000 : 480,
              child: context.twoColumn
                  ? _WideLobby(
                room: room,
                roomId: widget.roomId,
                playersAsync: playersAsync,
                user: user,
                isHost: isHost,
                starting: _starting,
                pulseAnim: _pulseAnim,
                onCopy: () => _copyCode(room.code),
                onStart: _startGame,
                gameService: _gameService,
              )
                  : _NarrowLobby(
                room: room,
                roomId: widget.roomId,
                playersAsync: playersAsync,
                user: user,
                isHost: isHost,
                starting: _starting,
                pulseAnim: _pulseAnim,
                onCopy: () => _copyCode(room.code),
                onStart: _startGame,
                gameService: _gameService,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Narrow (mobile/tablet) — stacked, scrollable ────────────────────────────

class _NarrowLobby extends StatelessWidget {
  final Room room;
  final String roomId;
  final AsyncValue playersAsync;
  final dynamic user;
  final bool isHost;
  final bool starting;
  final Animation<double> pulseAnim;
  final VoidCallback onCopy;
  final VoidCallback onStart;
  final GameService gameService;

  const _NarrowLobby({
    required this.room, required this.roomId, required this.playersAsync, required this.user,
    required this.isHost, required this.starting, required this.pulseAnim,
    required this.onCopy, required this.onStart, required this.gameService,
  });

  @override
  Widget build(BuildContext context) {
    final listHeight = context.screenHeight * 0.4;

    return Column(
      children: [
        _RoomCodeCard(code: room.code, onCopy: onCopy),
        Gap(context.fs(16, max: 24)),
        SizedBox(
          height: listHeight,
          child: playersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (players) => _PlayersList(players: players, user: user, room: room),
          ),
        ),
        Gap(context.fs(12, max: 20)),
        if (isHost)
          _HostControls(
            room: room,
            roomId: roomId,
            gameService: gameService,
            playerCount: playersAsync.valueOrNull?.length ?? 0,
            starting: starting,
            onStart: onStart,
          )
        else
          _WaitingIndicator(pulseAnim: pulseAnim),
      ],
    );
  }
}

// ── Wide (desktop) — two columns ─────────────────────────────────────────────

class _WideLobby extends StatelessWidget {
  final Room room;
  final String roomId;
  final AsyncValue playersAsync;
  final dynamic user;
  final bool isHost;
  final bool starting;
  final Animation<double> pulseAnim;
  final VoidCallback onCopy;
  final VoidCallback onStart;
  final GameService gameService;

  const _WideLobby({
    required this.room, required this.roomId, required this.playersAsync, required this.user,
    required this.isHost, required this.starting, required this.pulseAnim,
    required this.onCopy, required this.onStart, required this.gameService,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _RoomCodeCard(code: room.code, onCopy: onCopy),
              Gap(context.fs(24, max: 36)),
              if (isHost)
                _HostControls(
                  room: room,
                  roomId: roomId,
                  gameService: gameService,
                  playerCount: playersAsync.valueOrNull?.length ?? 0,
                  starting: starting,
                  onStart: onStart,
                )
              else
                _WaitingIndicator(pulseAnim: pulseAnim),
            ],
          ),
        ),
        SizedBox(width: context.fs(24, max: 48)),
        Expanded(
          flex: 5,
          child: SizedBox(
            height: context.screenHeight * 0.6,
            child: playersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (players) => _PlayersList(players: players, user: user, room: room),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared players list ──────────────────────────────────────────────────────

class _PlayersList extends StatelessWidget {
  final List players;
  final dynamic user;
  final Room room;
  const _PlayersList({required this.players, required this.user, required this.room});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.people, size: context.ff(16, max: 20), color: Colors.white54),
          SizedBox(width: context.fs(8, max: 10)),
          Text('Players (${players.length})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.ff(14, max: 18))),
          const Spacer(),
          if (players.length < 2)
            Text('Need at least 2',
                style: TextStyle(color: Colors.amber, fontSize: context.ff(11, max: 13))),
        ]),
        Gap(context.fs(10, max: 16)),
        Expanded(
          child: ListView.separated(
            itemCount: players.length,
            separatorBuilder: (_, __) => Gap(context.fs(6, max: 10)),
            itemBuilder: (_, i) {
              final p = players[i];
              return _PlayerTile(
                displayName: p.displayName,
                isMe: p.id == user?.uid,
                isHost: p.id == room.hostId,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Room Code Card ──────────────────────────────────────────────────────────

class _RoomCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  const _RoomCodeCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(16, max: 28), vertical: context.fs(16, max: 28)),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.purpleAccent.withOpacity(0.2),
          Colors.deepPurple.withOpacity(0.1),
        ]),
        borderRadius: BorderRadius.circular(context.fs(14, max: 22)),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('Room Code',
              style: TextStyle(color: Colors.white54, fontSize: context.ff(11, max: 13))),
          Gap(context.fs(8, max: 12)),
          Text(code,
              style: TextStyle(
                fontSize: context.ff(30, max: 46),
                fontWeight: FontWeight.w900,
                letterSpacing: context.fs(6, max: 12),
                color: Colors.purpleAccent,
              )),
          Gap(context.fs(10, max: 16)),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: Icon(Icons.copy, size: context.ff(13, max: 16)),
            label: Text('Copy Code', style: TextStyle(fontSize: context.ff(11, max: 13))),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                  horizontal: context.fs(14, max: 20), vertical: context.fs(6, max: 10)),
            ),
          ),
          Gap(context.fs(6, max: 10)),
          Text('Share this code with friends to join',
              style: TextStyle(color: Colors.white38, fontSize: context.ff(10, max: 12))),
        ],
      ),
    );
  }
}

// ── Player Tile ──────────────────────────────────────────────────────────────

class _PlayerTile extends StatelessWidget {
  final String displayName;
  final bool isMe;
  final bool isHost;
  const _PlayerTile({required this.displayName, required this.isMe, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(12, max: 20), vertical: context.fs(10, max: 16)),
      decoration: BoxDecoration(
        color: isMe ? Colors.purpleAccent.withOpacity(0.12) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(context.fs(10, max: 14)),
        border: Border.all(
            color: isMe ? Colors.purpleAccent.withOpacity(0.5) : Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: context.ff(16, max: 22),
            backgroundColor:
            isHost ? Colors.amber.withOpacity(0.2) : Colors.purpleAccent.withOpacity(0.2),
            child: Text(displayName[0].toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: context.ff(13, max: 16),
                    color: isHost ? Colors.amber : Colors.purpleAccent)),
          ),
          SizedBox(width: context.fs(10, max: 14)),
          Expanded(
            child: Text(displayName,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.ff(13, max: 16)),
                overflow: TextOverflow.ellipsis),
          ),
          Row(children: [
            if (isHost) _Badge(label: 'Host', color: Colors.amber),
            if (isMe) ...[
              SizedBox(width: context.fs(5, max: 8)),
              _Badge(label: 'You', color: Colors.purpleAccent),
            ],
          ]),
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
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(6, max: 10), vertical: context.fs(2, max: 4)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: context.ff(9, max: 12), fontWeight: FontWeight.bold)),
    );
  }
}

// ── Host Controls (settings + start) ─────────────────────────────────────────
//
// Difficulty is intentionally NOT exposed here — it's auto-randomized and
// weighted server-side per round (bug #5). Only year range and song count
// are host-configurable.

class _HostControls extends StatefulWidget {
  final Room room;
  final String roomId;
  final GameService gameService;
  final int playerCount;
  final bool starting;
  final VoidCallback onStart;

  const _HostControls({
    required this.room,
    required this.roomId,
    required this.gameService,
    required this.playerCount,
    required this.starting,
    required this.onStart,
  });

  @override
  State<_HostControls> createState() => _HostControlsState();
}

class _HostControlsState extends State<_HostControls> {
  late RangeValues _yearRange;
  late int _songCount;

  static const _minYear = 1950;
  static const _maxYear = 2029;
  static const _minSongs = 5;
  static const _maxSongs = 25;

  @override
  void initState() {
    super.initState();
    _yearRange = RangeValues(
      widget.room.yearFrom.toDouble().clamp(_minYear.toDouble(), _maxYear.toDouble()),
      widget.room.yearTo.toDouble().clamp(_minYear.toDouble(), _maxYear.toDouble()),
    );
    _songCount = widget.room.totalRounds.clamp(_minSongs, _maxSongs);
  }

  void _commitYearRange(RangeValues values) {
    setState(() => _yearRange = values);
    widget.gameService.updateRoomSettings(
      widget.roomId,
      yearRangeStart: values.start.round(),
      yearRangeEnd: values.end.round(),
      totalRounds: _songCount,
    );
  }

  void _commitSongCount(int count) {
    setState(() => _songCount = count);
    widget.gameService.updateRoomSettings(
      widget.roomId,
      yearRangeStart: _yearRange.start.round(),
      yearRangeEnd: _yearRange.end.round(),
      totalRounds: count,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart = widget.playerCount >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Year range ──────────────────────────────────────────────
        Row(
          children: [
            Text('Song Era', style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.ff(12, max: 15))),
            const Spacer(),
            Text(
              '${_yearRange.start.round()}s – ${_yearRange.end.round()}s',
              style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: context.ff(12, max: 15)),
            ),
          ],
        ),
        RangeSlider(
          values: _yearRange,
          min: _minYear.toDouble(),
          max: _maxYear.toDouble(),
          divisions: (_maxYear - _minYear) ~/ 10,
          activeColor: Colors.purpleAccent,
          onChanged: (v) => setState(() => _yearRange = v),
          onChangeEnd: _commitYearRange,
        ),
        Gap(context.fs(10, max: 16)),

        // ── Song count ──────────────────────────────────────────────
        Row(
          children: [
            Text('Number of Songs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: context.ff(12, max: 15))),
            const Spacer(),
            Text(
              '$_songCount',
              style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: context.ff(12, max: 15)),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.white54,
              onPressed: _songCount > _minSongs ? () => _commitSongCount(_songCount - 1) : null,
            ),
            Expanded(
              child: Slider(
                value: _songCount.toDouble(),
                min: _minSongs.toDouble(),
                max: _maxSongs.toDouble(),
                divisions: _maxSongs - _minSongs,
                activeColor: Colors.purpleAccent,
                label: '$_songCount',
                onChanged: (v) => setState(() => _songCount = v.round()),
                onChangeEnd: (v) => _commitSongCount(v.round()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.white54,
              onPressed: _songCount < _maxSongs ? () => _commitSongCount(_songCount + 1) : null,
            ),
          ],
        ),
        Gap(context.fs(14, max: 20)),

        if (!canStart)
          Padding(
            padding: EdgeInsets.only(bottom: context.fs(8, max: 12)),
            child: Text(
              'Waiting for at least 1 more player to join...',
              style: TextStyle(color: Colors.white38, fontSize: context.ff(11, max: 13)),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (widget.starting || !canStart) ? null : widget.onStart,
            icon: widget.starting
                ? SizedBox(
                width: context.ff(16, max: 20),
                height: context.ff(16, max: 20),
                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(Icons.play_arrow_rounded, size: context.ff(20, max: 26)),
            label: Text(widget.starting ? 'Starting...' : 'Start Game',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: context.ff(14, max: 17))),
            style: FilledButton.styleFrom(
              backgroundColor: canStart ? Colors.purpleAccent : Colors.grey.shade700,
              padding: EdgeInsets.symmetric(vertical: context.fs(14, max: 20)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Waiting Indicator ────────────────────────────────────────────────────────

class _WaitingIndicator extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _WaitingIndicator({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnim,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.fs(16, max: 24), vertical: context.fs(12, max: 18)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(context.fs(10, max: 14)),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: context.ff(14, max: 18),
              height: context.ff(14, max: 18),
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
            ),
            SizedBox(width: context.fs(10, max: 14)),
            Flexible(
              child: Text(
                'Waiting for host to start the game...',
                style: TextStyle(color: Colors.white54, fontSize: context.ff(12, max: 15)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}