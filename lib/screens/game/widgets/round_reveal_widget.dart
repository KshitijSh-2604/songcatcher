import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/song.dart';
import '../../../utils/responsive.dart';
import '../../../providers/room_provider.dart';

class RoundRevealWidget extends ConsumerStatefulWidget {
  final String roomId;
  final Song song;
  final bool isHost;
  final bool isSkipped;
  final VoidCallback onNextRound;

  const RoundRevealWidget({
    super.key,
    required this.roomId,
    required this.song,
    required this.isHost,
    this.isSkipped = false,
    required this.onNextRound,
  });

  @override
  ConsumerState<RoundRevealWidget> createState() => _RoundRevealWidgetState();
}

class _RoundRevealWidgetState extends ConsumerState<RoundRevealWidget>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _timerCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;
  
  // ⏸️ Pause tracking
  DateTime? _timerStartedAt;
  int       _remainingSeconds = 15;
  Timer?    _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    
    _timerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 15));
        
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    
    _ctrl.forward();
    _startTimer(15);
  }

  void _startTimer(int seconds) {
    _autoNextTimer?.cancel();
    _timerCtrl.duration = Duration(seconds: seconds);
    // Restart animation from the visual point that matches the remaining time
    _timerCtrl.forward(from: 1.0 - (seconds / 15.0));
    
    _timerStartedAt = DateTime.now();
    _remainingSeconds = seconds;

    _autoNextTimer = Timer(Duration(seconds: seconds), () {
       if (mounted && widget.isHost) {
          final room = ref.read(roomProvider(widget.roomId)).valueOrNull;
          // 🛡️ Final guard to ensure we don't skip while host has game paused
          if (room != null && !room.isPaused) {
            widget.onNextRound();
          }
       }
    });
  }

  @override
  void didUpdateWidget(RoundRevealWidget old) {
    super.didUpdateWidget(old);
    
    final room = ref.read(roomProvider(widget.roomId)).valueOrNull;
    if (room == null) return;

    // ⏸️ React to Pause
    if (room.isPaused) {
      if (_autoNextTimer?.isActive ?? false) {
        final elapsed = DateTime.now().difference(_timerStartedAt!).inSeconds;
        _remainingSeconds = (_remainingSeconds - elapsed).clamp(0, 15);
        _autoNextTimer?.cancel();
        _timerCtrl.stop();
      }
    } else {
      // 🔄 React to Resume
      if (!(_autoNextTimer?.isActive ?? false) && _remainingSeconds > 0) {
        _startTimer(_remainingSeconds);
      }
    }
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _ctrl.dispose();
    _timerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayBg = isDark ? Colors.black : const Color(0xFFF0F4F8);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          color: overlayBg,
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _timerCtrl,
                builder: (context, _) => LinearProgressIndicator(
                  value: 1.0 - _timerCtrl.value,
                  minHeight: 6,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFFFFFF00),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.fw(380, max: 860)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(context.fs(16, max: 32)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NeubrutalistContainer(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: context.fs(14, max: 20),
                                      vertical: context.fs(5, max: 8)),
                                  color: widget.isSkipped ? Colors.red : const Color(0xFF00FF00),
                                  shadowOffset: 0,
                                  child: Text(
                                    widget.isSkipped ? '🚫 ROUND SKIPPED' : '✅ ROUND OVER',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      fontSize: 14,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                Gap(context.fs(16, max: 24)),

                                if (widget.isSkipped)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Text(
                                      'Most players voted to skip. No points were awarded.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red.shade700, fontSize: 13),
                                    ),
                                  ),

                                context.twoColumn
                                    ? _WideCard(song: widget.song, roomId: widget.roomId)
                                    : _NarrowCard(song: widget.song, roomId: widget.roomId),

                                Gap(context.fs(16, max: 24)),
                              ],
                            ),
                          ),
                        ),

                        // ── Bottom Fixed Action Area ──────────────────────────────
                        Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, context.vPad),
                          child: widget.isHost
                              ? SizedBox(
                                  width: double.infinity,
                                  child: NeubrutalistButton(
                                    onPressed: widget.onNextRound,
                                    label: 'NEXT ROUND →',
                                    color: const Color(0xFFFFFF00),
                                  ),
                                )
                              : Text(
                                  'Waiting for host to continue...',
                                  style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: context.ff(12, max: 14)),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrowCard extends StatelessWidget {
  final Song song;
  final String roomId;
  const _NarrowCard({required this.song, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return NeubrutalistContainer(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      shadowOffset: 8,
      child: Column(
        children: [
          _AlbumArt(song: song, size: context.fs(110, max: 160)),
          Gap(context.fs(16, max: 24)),
          _SongInfo(song: song),
          Gap(context.fs(20, max: 30)),
          _CorrectGuessers(roomId: roomId),
        ],
      ),
    );
  }
}

class _WideCard extends StatelessWidget {
  final Song song;
  final String roomId;
  const _WideCard({required this.song, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return NeubrutalistContainer(
      color: Colors.white,
      padding: const EdgeInsets.all(32),
      shadowOffset: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AlbumArt(song: song, size: context.fs(140, max: 220)),
          SizedBox(width: context.fs(24, max: 40)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SongInfo(song: song, textAlign: TextAlign.left),
                Gap(context.fs(20, max: 30)),
                _CorrectGuessers(roomId: roomId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final Song song;
  final double size;
  const _AlbumArt({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.14),
        border: Border.all(color: const Color(0xFFD4D9E2), width: 2),
        image: song.albumArtUrl.isNotEmpty
            ? DecorationImage(
          image: NetworkImage(song.albumArtUrl),
          fit: BoxFit.cover,
        )
            : null,
      ),
      child: song.albumArtUrl.isEmpty
          ? Center(
          child: Text('🎵',
              style: TextStyle(fontSize: size * 0.38)))
          : null,
    );
  }
}

class _SongInfo extends StatelessWidget {
  final Song song;
  final TextAlign textAlign;
  const _SongInfo({required this.song, this.textAlign = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          song.title,
          style: TextStyle(
              fontSize: context.ff(18, max: 28),
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge?.color),
          textAlign: textAlign,
        ),
        Gap(context.fs(5, max: 8)),
        Text(
          song.artist,
          style: TextStyle(
              fontSize: context.ff(13, max: 18),
              color: Theme.of(context).textTheme.bodyMedium?.color),
          textAlign: textAlign,
        ),
        Gap(context.fs(4, max: 6)),
        Text(
          song.album.isNotEmpty ? song.album : '',
          style: TextStyle(
              fontSize: context.ff(11, max: 14),
              color: Theme.of(context).hintColor),
          textAlign: textAlign,
        ),
        Gap(context.fs(10, max: 16)),
        Wrap(
          spacing: context.fs(5, max: 8),
          runSpacing: context.fs(4, max: 6),
          alignment: textAlign == TextAlign.left
              ? WrapAlignment.start
              : WrapAlignment.center,
          children: [
            _Tag(label: '${song.year}'),
            _Tag(label: song.genre),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(8, max: 12), vertical: context.fs(2, max: 4)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(label,
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color, 
              fontSize: context.ff(10, max: 13), 
              fontWeight: FontWeight.bold)),
    );
  }
}

class _CorrectGuessers extends StatelessWidget {
  final String roomId;
  const _CorrectGuessers({required this.roomId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('players')
          .where('hasGuessedCorrectly', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Text(
            'Nobody caught this one! 🙈',
            style: TextStyle(
                color: Theme.of(context).hintColor, 
                fontSize: context.ff(13, max: 15)),
          );
        }

        final names = snap.data!.docs
            .map((d) =>
        (d.data() as Map<String, dynamic>)['displayName'] as String? ??
            'Player')
            .toList();

        return Column(
          children: [
            Text('✅ Caught by',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color, 
                    fontSize: context.ff(11, max: 13))),
            Gap(context.fs(5, max: 8)),
            Wrap(
              spacing: context.fs(5, max: 8),
              runSpacing: context.fs(5, max: 8),
              alignment: WrapAlignment.center,
              children: names
                  .map((name) => Chip(
                label: Text(name,
                    style:
                    TextStyle(fontSize: context.ff(11, max: 13), color: Colors.green.shade900)),
                backgroundColor: Colors.green.shade50,
                side: BorderSide(color: Colors.green.shade200),
              ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}
