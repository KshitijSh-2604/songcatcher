import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class ItunesService {
  final _rand = Random();

  static const String _base = 'https://itunes.apple.com';

  // Generic decade-based queries that can be prefixed with the vibe/genre
  static const List<String> _genericQueries = [
    'hits', 'classics', 'popular', 'best of', 'essentials'
  ];

  Future<List<Map<String, dynamic>>> _search(String term, {int limit = 50, int offset = 0, String country = 'IN'}) async {
    final encoded = Uri.encodeQueryComponent(term);
    final url = Uri.parse(
      '$_base/search?term=$encoded&media=music&entity=song'
          '&limit=$limit&offset=$offset&country=$country',
    );

    try {
      final res = await http.get(url, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(
        (data['results'] as List? ?? []).where((t) => t != null && (t['previewUrl'] as String?) != null),
      );
    } catch (e) {
      debugPrint('iTunes search error: $e');
      return [];
    }
  }

  Song? _trackToSong(Map<String, dynamic> t, {int rank = 25, String genre = 'Mixed'}) {
    final previewUrl = t['previewUrl'] as String?;
    if (previewUrl == null) return null;

    final trackId = (t['trackId'] as num?)?.toInt() ?? 0;
    final title = t['trackName'] as String? ?? '';
    final artist = t['artistName'] as String? ?? '';
    final album = t['collectionName'] as String? ?? '';
    final albumArt = (t['artworkUrl100'] as String? ?? '').replaceAll('100x100', '640x640');
    final rawDate = t['releaseDate'] as String? ?? '2000-01-01';
    final year = int.tryParse(rawDate.split('-').first) ?? 2000;
    final decade = '${(year ~/ 10) * 10}s';
    
    // Derived language/genre based on track data or query context
    final isHindi = t['primaryGenreName'] == 'Bollywood' || artist.toLowerCase().contains('arijit') || title.toLowerCase().contains('dil');

    return Song(
      id: 'itunes_$trackId',
      title: title,
      artist: artist,
      album: album,
      audioUrl: previewUrl,
      albumArtUrl: albumArt,
      genre: genre,
      language: isHindi ? 'Hindi' : 'English',
      decade: decade,
      difficulty: _getDifficulty(rank, rawDate),
      popularity: (50 - rank).clamp(0, 100),
      silenceOffset: 0,
      hint1: '$genre song',
      hint2: 'Released in the $decade',
      hint3: 'By $artist',
      spotifyId: 'itunes_$trackId',
      year: year,
    );
  }

  String _getDifficulty(int rank, String releaseDate) {
    final year = int.tryParse(releaseDate.split('-').first) ?? 2000;
    final age = DateTime.now().year - year;
    final score = (50 - rank).clamp(0, 50) + (age > 25 ? 20 : age > 10 ? 8 : 0);
    if (score >= 40) return 'easy';
    if (score >= 25) return 'medium';
    if (score >= 12) return 'hard';
    return 'hardcore';
  }

  Future<List<Song>> fetchSongsForRoom({
    required String genre,
    required int yearFrom,
    required int yearTo,
    int count = 20,
  }) async {
    final queries = <String>[];
    String country = 'US';

    if (genre == 'Bollywood') {
      queries.addAll(['bollywood hits', 'hindi film songs', 'bollywood classics']);
      country = 'IN';
    } else if (genre == 'English') {
      queries.addAll(['english hits', 'pop hits', 'rock essentials']);
      country = 'US';
    } else if (genre == 'International') {
      queries.addAll(['global hits', 'international top songs', 'world music hits']);
      country = 'US';
    } else if (genre.endsWith('s')) {
      final decade = genre.substring(0, 4);
      queries.add('popular songs $decade');
      queries.add('hits $decade');
    } else {
      for (final q in _genericQueries) {
        queries.add('$genre $q');
      }
    }
    queries.shuffle(_rand);

    final List<Song> pool = [];
    final Set<int> seen = {};

    for (final query in queries) {
      if (pool.length >= count * 4) break;
      final tracks = await _search(query, limit: 50, country: country);
      for (var i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        final id = (t['trackId'] as num?)?.toInt() ?? 0;
        if (id == 0 || seen.contains(id)) continue;
        seen.add(id);

        final song = _trackToSong(t, rank: i, genre: genre);
        if (song == null) continue;
        if (song.year < yearFrom || song.year > yearTo) continue;
        if (song.difficulty == 'hardcore') continue;
        pool.add(song);
      }
    }

    if (pool.isEmpty) return [];
    
    pool.shuffle(_rand);
    return pool.take(count).toList();
  }
}
