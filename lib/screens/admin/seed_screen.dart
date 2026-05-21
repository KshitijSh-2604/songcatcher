import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/spotify_service.dart';

// Curated playlists — same as what was in Cloud Functions
const _playlists = [
  {'id': '37i9dQZF1DXcBWIGoYBM5M', 'language': 'English', 'genre': 'Pop'},
  {'id': '37i9dQZF1DX0XUsuxWHRQd', 'language': 'English', 'genre': 'Hip-Hop'},
  {'id': '37i9dQZF1DWXRqgorJj26U', 'language': 'English', 'genre': 'Rock'},
  {'id': '37i9dQZF1DX4SBhb3fqCJd', 'language': 'English', 'genre': 'R&B'},
  {'id': '37i9dQZF1DXb57FjYWz00c', 'language': 'English', 'genre': '80s'},
  {'id': '37i9dQZF1DXbTxeAdrVG2l', 'language': 'English', 'genre': '90s'},
  {'id': '37i9dQZF1DX10zKzsJ2jva', 'language': 'Spanish', 'genre': 'Reggaeton'},
  {'id': '37i9dQZF1DXdgz8ZB7c6mk', 'language': 'French', 'genre': 'Pop'},
  {'id': '37i9dQZF1DX9tPFAJQI8AP', 'language': 'Korean', 'genre': 'K-Pop'},
];

class SeedScreen extends StatefulWidget {
  const SeedScreen({super.key});

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  final _spotify = SpotifyService();
  final _db = FirebaseFirestore.instance;

  bool _running = false;
  String _status = '';
  int _added = 0;
  int _skipped = 0;

  Future<void> _seed() async {
    setState(() {
      _running = true;
      _added = 0;
      _skipped = 0;
      _status = 'Starting...';
    });

    try {
      for (final playlist in _playlists) {
        setState(() => _status =
        'Fetching ${playlist['language']} ${playlist['genre']}...');

        final tracks = await _spotify.getPlaylistTracks(playlist['id']!);

        for (final track in tracks) {
          final docId = 'spotify_${track['id']}';
          final ref = _db.collection('songs').doc(docId);
          final existing = await ref.get();

          if (existing.exists) {
            setState(() => _skipped++);
            continue;
          }

          final doc = _spotify.trackToSongDoc(
            track,
            playlist['language']!,
            playlist['genre']!,
          );

          await ref.set({
            ...doc,
            'addedAt': FieldValue.serverTimestamp(),
          });

          setState(() => _added++);
        }
      }

      setState(() => _status = '✅ Done! $_added songs added, $_skipped skipped.');
    } catch (e) {
      setState(() => _status = '❌ Error: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Song Library')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Text(
                '⚠️  Run this once to populate the song library from Spotify. '
                    'It may take a few minutes. Keep the screen open.',
                style: TextStyle(color: Colors.amber, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),

            if (_status.isNotEmpty) ...[
              Text(_status,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Stat(label: 'Added', value: _added, color: Colors.greenAccent),
                  const SizedBox(width: 24),
                  _Stat(label: 'Skipped', value: _skipped, color: Colors.white38),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (_running)
              const LinearProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _seed,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Seed Songs from Spotify'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}