import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../../../utils/responsive.dart';

class RoundRevealWidget extends StatefulWidget {
  final String roomId;
  final Song song;
  final bool isHost;
  final VoidCallback onNextRound;

  const RoundRevealWidget({
    super.key,
    required this.roomId,
    required this.song,
    required this.isHost,
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          color: const Color(0xEE0F0F1A),
          child: Center(
            child: ConstrainedBox(
              // Wider on desktop — up to 860px so the two-column layout
              // has room to breathe.
              constraints: BoxConstraints(maxWidth: context.fw(380, max: 860)),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.fs(20, max: 40)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Header pill ─────────────────────────────────────
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.fs(14, max: 20),
                          vertical: context.fs(5, max: 8)),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                        Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        '🎵 Round Over!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent,
                          fontSize: context.ff(13, max: 16),
                        ),
                      ),
                    ),
                    Gap(context.fs(22, max: 34)),

                    // ── Main card — stacked on narrow, side-by-side on wide ──
                    context.twoColumn
                        ? _WideCard(song: widget.song, roomId: widget.roomId)
                        : _NarrowCard(song: widget.song, roomId: widget.roomId),

                    Gap(context.fs(20, max: 32)),

                    // ── Next round / waiting ─────────────────────────────
                    if (widget.isHost)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.onNextRound,
                          icon: Icon(Icons.skip_next_rounded,
                              size: context.ff(18, max: 22)),
                          label: Text('Next Round',
                              style: TextStyle(fontSize: context.ff(14, max: 17))),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            padding: EdgeInsets.symmetric(
                                vertical: context.fs(12, max: 18)),
                          ),
                        ),
                      )
                    else
                      Text(
                        'Waiting for host to continue...',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: context.ff(12, max: 14)),
                      ),
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

// ── Narrow layout (mobile/tablet) — stacked ──────────────────────────────────

class _NarrowCard extends StatelessWidget {
  final Song song;
  final String roomId;
  const _NarrowCard({required this.song, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AlbumArt(song: song, size: context.fs(110, max: 160)),
        Gap(context.fs(16, max: 24)),
        _SongInfo(song: song),
        Gap(context.fs(20, max: 30)),
        _CorrectGuessers(roomId: roomId),
      ],
    );
  }
}

// ── Wide layout (desktop) — album art left, info right ───────────────────────

class _WideCard extends StatelessWidget {
  final Song song;
  final String roomId;
  const _WideCard({required this.song, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

// ── Album art ────────────────────────────────────────────────────────────────

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
        color: Colors.purpleAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(size * 0.14),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
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

// ── Song title + artist + tags ────────────────────────────────────────────────

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
              fontWeight: FontWeight.w900),
          textAlign: textAlign,
        ),
        Gap(context.fs(5, max: 8)),
        Text(
          song.artist,
          style: TextStyle(
              fontSize: context.ff(13, max: 18),
              color: Colors.white60),
          textAlign: textAlign,
        ),
        Gap(context.fs(4, max: 6)),
        Text(
          song.album.isNotEmpty ? song.album : '',
          style: TextStyle(
              fontSize: context.ff(11, max: 14),
              color: Colors.white38),
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
            _Tag(label: song.decade),
            _Tag(label: song.difficultyLabel),
          ],
        ),
      ],
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.fs(8, max: 12), vertical: context.fs(2, max: 4)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label,
          style: TextStyle(
              color: Colors.white60, fontSize: context.ff(10, max: 13))),
    );
  }
}

// ── Correct guessers ──────────────────────────────────────────────────────────

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
                color: Colors.white38, fontSize: context.ff(13, max: 15)),
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
                    color: Colors.white54, fontSize: context.ff(11, max: 13))),
            Gap(context.fs(5, max: 8)),
            Wrap(
              spacing: context.fs(5, max: 8),
              runSpacing: context.fs(5, max: 8),
              alignment: WrapAlignment.center,
              children: names
                  .map((name) => Chip(
                label: Text(name,
                    style:
                    TextStyle(fontSize: context.ff(11, max: 13))),
                backgroundColor: Colors.green.withOpacity(0.15),
                side: BorderSide(color: Colors.green.withOpacity(0.4)),
              ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}