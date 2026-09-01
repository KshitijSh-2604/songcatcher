import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../../../utils/responsive.dart';

class RoundRevealWidget extends StatefulWidget {
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
  State<RoundRevealWidget> createState() => _RoundRevealWidgetState();
}

class _RoundRevealWidgetState extends State<RoundRevealWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    _autoNextTimer = Timer(const Duration(seconds: 15), () {
       if (mounted && widget.isHost) widget.onNextRound();
    });
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _ctrl.dispose();
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
              _TimerBar(duration: 15),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.fw(380, max: 860)),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(context.fs(20, max: 40)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          Gap(context.fs(22, max: 34)),

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

                          Gap(context.fs(20, max: 32)),

                          if (widget.isHost)
                            SizedBox(
                              width: double.infinity,
                              child: NeubrutalistButton(
                                onPressed: widget.onNextRound,
                                label: 'NEXT ROUND →',
                                color: const Color(0xFFFFFF00),
                              ),
                            )
                          else
                            Text(
                              'Waiting for host to continue...',
                              style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: context.ff(12, max: 14)),
                            ),
                        ],
                      ),
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

class _TimerBar extends StatefulWidget {
  final int duration;
  const _TimerBar({required this.duration});
  @override
  State<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<_TimerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Duration(seconds: widget.duration));
    _ctrl.forward();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => LinearProgressIndicator(
        value: 1.0 - _ctrl.value,
        minHeight: 6,
        backgroundColor: Colors.transparent,
        color: const Color(0xFFFFFF00),
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