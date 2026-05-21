import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/song.dart';

class RoundRevealWidget extends StatefulWidget {
  final String roomId;
  final String songId;
  final bool isHost;
  final VoidCallback onNextRound;

  const RoundRevealWidget({
    super.key,
    required this.roomId,
    required this.songId,
    required this.isHost,
    required this.onNextRound,
  });

  @override
  State<RoundRevealWidget> createState() => _RoundRevealWidgetState();
}

class _RoundRevealWidgetState extends State<RoundRevealWidget>
    with SingleTickerProviderStateMixin {
  Song? _song;
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _loadSong();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadSong() async {
    final doc = await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get();
    if (mounted && doc.exists) {
      setState(() =>
      _song = Song.fromMap(doc.id, doc.data()!));
    }
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                        Colors.purpleAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.purpleAccent
                                .withOpacity(0.4)),
                      ),
                      child: const Text(
                        '🎵 Round Over!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Song card
                    if (_song != null) ...[
                      // Album art placeholder
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color:
                          Colors.purpleAccent.withOpacity(0.15),
                          borderRadius:
                          BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.purpleAccent
                                  .withOpacity(0.3)),
                          image: _song!.albumArtUrl != null
                              ? DecorationImage(
                            image: NetworkImage(
                                _song!.albumArtUrl!),
                            fit: BoxFit.cover,
                          )
                              : null,
                        ),
                        child: _song!.albumArtUrl == null
                            ? const Center(
                            child: Text('🎵',
                                style: TextStyle(
                                    fontSize: 44)))
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Song info
                      Text(
                        _song!.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _song!.artist,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          _Tag(label: _song!.language),
                          const SizedBox(width: 6),
                          _Tag(label: _song!.decade),
                        ],
                      ),
                    ] else ...[
                      const CircularProgressIndicator(),
                    ],

                    const SizedBox(height: 32),

                    // Who guessed right
                    _CorrectGuessers(roomId: widget.roomId),
                    const SizedBox(height: 24),

                    // Next round (host only)
                    if (widget.isHost)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.onNextRound,
                          icon: const Icon(
                              Icons.skip_next_rounded),
                          label: const Text('Next Round'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                            Colors.purpleAccent,
                            padding:
                            const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Waiting for host to continue...',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 13),
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

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white60, fontSize: 11),
      ),
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
          return const Text(
            'Nobody caught this one! 🙈',
            style: TextStyle(color: Colors.white38),
          );
        }

        final names = snap.data!.docs
            .map((d) =>
        (d.data() as Map<String, dynamic>)['displayName']
        as String? ??
            'Player')
            .toList();

        return Column(
          children: [
            const Text(
              '✅ Caught by',
              style: TextStyle(
                  color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: names
                  .map((name) => Chip(
                label: Text(name,
                    style:
                    const TextStyle(fontSize: 12)),
                backgroundColor: Colors.green
                    .withOpacity(0.15),
                side: BorderSide(
                    color:
                    Colors.green.withOpacity(0.4)),
              ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}