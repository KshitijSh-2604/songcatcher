import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/room.dart';
import '../../../models/song.dart';
import '../../../services/audio_service.dart';

class ClipPlayerWidget extends StatefulWidget {
  final Room room;
  final SongAudioService audioService;
  final Future<void> Function(String songId, String audioUrl) onSongLoad;
  final bool isHost;
  final Future<void> Function(int seconds) onReveal;
  final Future<void> Function() onEndRound;

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

class _ClipPlayerWidgetState extends State<ClipPlayerWidget> {
  Song? _song;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSong();
  }

  @override
  void didUpdateWidget(ClipPlayerWidget old) {
    super.didUpdateWidget(old);
    if (old.room.currentSongId != widget.room.currentSongId) {
      _loadSong();
    }
  }

  Future<void> _loadSong() async {
    final songId = widget.room.currentSongId;
    if (songId == null) return;
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('songs')
          .doc(songId)
          .get();
      if (!doc.exists || !mounted) return;
      final song = Song.fromMap(doc.id, doc.data()!);
      setState(() => _song = song);
      await widget.onSongLoad(song.id, song.audioUrl);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playClip() async {
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
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clip reveal bars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [3, 5, 10].map((s) {
              final revealed = widget.room.revealedSeconds >= s;
              final isCurrent = widget.room.revealedSeconds == s;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: s * 9.0,
                height: 44,
                decoration: BoxDecoration(
                  color: revealed
                      ? Colors.purpleAccent
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(6),
                  border: isCurrent
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: revealed
                      ? [BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.4),
                    blurRadius: 8,
                  )]
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
          const SizedBox(height: 20),

          // Play button
          if (_loading)
            const CircularProgressIndicator()
          else
            FilledButton.icon(
              onPressed: _song == null || _playing ? null : _playClip,
              icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
              label: Text(
                _playing
                    ? 'Playing ${widget.room.revealedSeconds}s...'
                    : 'Play ${widget.room.revealedSeconds}s Clip',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
            ),

          // Host controls
          if (widget.isHost) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (widget.room.revealedSeconds < 5)
                  OutlinedButton.icon(
                    onPressed: () => widget.onReveal(5),
                    icon: const Icon(Icons.expand_more, size: 16),
                    label: const Text('Reveal 5s'),
                  ),
                if (widget.room.revealedSeconds < 10)
                  OutlinedButton.icon(
                    onPressed: () => widget.onReveal(10),
                    icon: const Icon(Icons.expand_more, size: 16),
                    label: const Text('Reveal 10s'),
                  ),
                FilledButton.icon(
                  onPressed: widget.onEndRound,
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('End Round'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}