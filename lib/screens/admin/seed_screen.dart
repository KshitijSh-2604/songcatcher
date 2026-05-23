import 'package:flutter/material.dart';
import '../../models/song.dart';
import '../../services/itunes_service.dart';

class SeedScreen extends StatefulWidget {
  const SeedScreen({super.key});

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  final _spotify = ItunesService();

  bool _running = false;
  String _status = '';
  List<Song> _songs = [];
  String _selectedGenre = 'Pop';
  String _selectedDifficulty = 'easy';

  static const _genres = [
    'Pop', 'Hip-Hop', 'Rock', 'R&B', 'Electronic',
    'K-Pop', 'Reggaeton', 'Bollywood', 'Indie', 'Mix',
  ];

  static const _difficulties = ['easy', 'medium', 'hard', 'hardcore'];

  Future<void> _test() async {
    setState(() {
      _running = true;
      _status = 'Fetching from Spotify...';
      _songs = [];
    });

    try {
      final songs = _selectedGenre == 'Mix'
          ? await _spotify.fetchMixedSongs(count: 10)
          : await _spotify.fetchSongsForRoom(
        difficulty: _selectedDifficulty,
        genre: _selectedGenre,
        count: 10,
      );

      setState(() {
        _songs = songs;
        _status = songs.isEmpty
            ? '⚠️  No songs with previews found for this combination.'
            : '✅ ${songs.length} songs fetched live from Spotify.';
      });
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spotify Debug')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Text(
                '✅  No seeding needed! Songs are fetched live from Spotify '
                    'when each game starts. Use this screen to test the connection.',
                style: TextStyle(color: Colors.green, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),

            // Genre picker
            const Text('Genre', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _genres.map((g) {
                final selected = g == _selectedGenre;
                return FilterChip(
                  label: Text(g),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedGenre = g),
                  selectedColor: Colors.purpleAccent.withOpacity(0.3),
                  labelStyle: TextStyle(
                    color: selected ? Colors.purpleAccent : Colors.white70,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Difficulty picker (hidden for Mix)
            if (_selectedGenre != 'Mix') ...[
              const Text('Difficulty', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: _difficulties.map((d) {
                  final selected = d == _selectedDifficulty;
                  final emoji = {'easy': '🟢', 'medium': '🟡', 'hard': '🔴', 'hardcore': '💀'}[d]!;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDifficulty = d),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.purpleAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? Colors.purpleAccent
                                : Colors.white12,
                          ),
                        ),
                        child: Text(
                          '$emoji\n${d[0].toUpperCase()}${d.substring(1)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.purpleAccent : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Test button
            FilledButton.icon(
              onPressed: _running ? null : _test,
              icon: _running
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.wifi_tethering_rounded),
              label: Text(_running ? 'Fetching...' : 'Test Spotify Connection'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Status
            if (_status.isNotEmpty)
              Text(_status,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),

            // Song list preview
            if (_songs.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              ..._songs.map((s) => _SongTile(song: s)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  const _SongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    final diffColor = {
      'easy':     Colors.green,
      'medium':   Colors.yellow,
      'hard':     Colors.orange,
      'hardcore': Colors.red,
    }[song.difficulty] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: song.albumArtUrl.isNotEmpty
                ? Image.network(song.albumArtUrl, width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _PlaceholderArt())
                : const _PlaceholderArt(),
          ),
          const SizedBox(width: 12),
          // Title + artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(song.artist,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Difficulty badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: diffColor.withOpacity(0.4)),
            ),
            child: Text(
              '${song.popularity}',
              style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt();
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    color: Colors.white10,
    child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
  );
}