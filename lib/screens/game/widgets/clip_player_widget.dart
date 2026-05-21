import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/room.dart';
import '../../../models/song.dart';
import '../../../services/audio_service.dart';

class ClipPlayerWidget extends StatefulWidget {
  final Room room;
  final SongAudioService audioService;
  final Future<void> Function(String, String, int) onSongLoad;
  final bool isHost;
  final Future<void> Function(int seconds) onReveal;
  final VoidCallback onEndRound;

  const ClipPlayerWidget({
    super.key,
    required this.room,
    required this.audioService,
    required this.onSongLoad,
    required this.isHost,
    required this.onReveal,
    required this.onEndRound,
  });

  @override
  State<ClipPlayerWidget> createState() => _ClipPlayerWidgetState();
}

class _ClipPlayerWidgetState extends State<ClipPlayerWidget>
    with SingleTickerProviderStateMixin {
  Song? _song;
  bool _playing = false;
  bool _loadingAudio = false;

  late final AnimationController _playCtrl;
  late final Animation<double> _playScale;

  @override
  void initState() {
    super.initState();
    _playCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _playScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _playCtrl, curve: Curves.easeInOut),
    );
    _loadSong();
  }

  @override
  void didUpdateWidget(ClipPlayerWidget old) {
    super.didUpdateWidget(old);
    if (old.room.currentSongId != widget.room.currentSongId) {
      setState(() => _song = null);
      _loadSong();
    }
  }

  @override
  void dispose() {
    _playCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSong() async {
    final songId = widget.room.currentSongId;
    if (songId == null) return;

    setState(() => _loadingAudio = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('songs')
          .doc(songId)
          .get();
      if (!doc.exists || !mounted) return;

      final song = Song.fromMap(doc.id, doc.data()!);
      setState(() => _song = song);
      await widget.onSongLoad(
          song.id, song.audioUrl, song.silenceOffset);
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _playClip() async {
    if (_playing || _song == null) return;
    _playCtrl.forward().then((_) => _playCtrl.reverse());
    setState(() => _playing = true);
    try {
      await widget.audioService.playClip(widget.room.revealedSeconds);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Clip reveal bars ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [3, 5, 10].map((s) {
              final revealed = widget.room.revealedSeconds >= s;
              final isCurrent = widget.room.revealedSeconds == s;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: s * 10.0,
                height: 46,
                decoration: BoxDecoration(
                  color: revealed
                      ? Colors.purpleAccent
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: revealed
                      ? [
                    BoxShadow(
                      color:
                      Colors.purpleAccent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${s}s',
                    style: TextStyle(
                      color: revealed ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // ── Play button ─────────────────────────────────────────────
          _loadingAudio
              ? const CircularProgressIndicator()
              : ScaleTransition(
            scale: _playScale,
            child: FilledButton.icon(
              onPressed:
              (_song == null || _playing) ? null : _playClip,
              icon: Icon(
                _playing ? Icons.graphic_eq : Icons.play_arrow_rounded,
                size: 22,
              ),
              label: Text(
                _playing
                    ? 'Playing ${widget.room.revealedSeconds}s...'
                    : 'Play ${widget.room.revealedSeconds}s Clip',
                style: const TextStyle(fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _playing
                    ? Colors.deepPurple
                    : Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 36, vertical: 14),
              ),
            ),
          ),

          // ── Host controls ───────────────────────────────────────────
          if (widget.isHost) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (widget.room.revealedSeconds < 5)
                  OutlinedButton.icon(
                    onPressed: () => widget.onReveal(5),
                    icon: const Icon(Icons.unfold_more, size: 15),
                    label: const Text('Reveal 5s'),
                  ),
                if (widget.room.revealedSeconds < 10)
                  OutlinedButton.icon(
                    onPressed: () => widget.onReveal(10),
                    icon: const Icon(Icons.unfold_more, size: 15),
                    label: const Text('Reveal 10s'),
                  ),
                FilledButton.icon(
                  onPressed: widget.onEndRound,
                  icon: const Icon(Icons.skip_next_rounded,
                      size: 16),
                  label: const Text('End Round'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}