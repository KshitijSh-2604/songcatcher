import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Uses Apple's iTunes Search API — no account, no API key, completely free.
/// Endpoint: https://itunes.apple.com/search
/// Returns 30-second M4A preview URLs for ~95% of tracks.
class ItunesService {
  final _rand = Random();

  static const _queries = {
    'Pop': [
      'pop hits 2024', 'pop hits 2023', 'pop 2022', 'pop hits 2021',
      'pop 2020', 'pop 2018 2019', 'pop 2015 2016 2017',
      'pop hits 2010s', 'pop hits 2000s', 'pop classics 1990s', 'pop 1980s',
    ],
    'Hip-Hop': [
      'rap 2024', 'hip hop 2023', 'rap hits 2022', 'hip hop 2021',
      'rap 2020', 'hip hop 2018 2019', 'rap 2015 2016 2017',
      'hip hop 2010s', 'rap classics 2000s', 'rap classics 1990s',
    ],
    'Rock': [
      'rock hits 2024', 'rock 2022 2023', 'rock hits 2020',
      'rock 2010s', 'rock 2000s', 'rock classics 1990s',
      'rock classics 1980s', 'rock classics 1970s', 'alternative rock',
    ],
    'R&B': [
      'rnb 2024', 'rnb hits 2022 2023', 'rnb 2020 2021',
      'rnb 2018 2019', 'rnb hits 2015 2016 2017',
      'soul rnb 2010s', 'rnb 2000s', 'soul classics',
    ],
    'Electronic': [
      'edm 2024', 'electronic dance 2023', 'edm hits 2022',
      'house music 2020 2021', 'electronic 2018 2019', 'dance hits 2010s',
    ],
    'Country': [
      'country hits 2024', 'country 2022 2023', 'country 2020 2021',
      'country hits 2018 2019', 'country 2010s', 'country classics 2000s',
    ],
    'K-Pop': [
      'kpop 2024', 'kpop hits 2023', 'kpop 2022',
      'kpop 2020 2021', 'kpop 2018 2019', 'kpop 2016 2017', 'kpop 2013 2014 2015',
    ],
    'Reggaeton': [
      'reggaeton 2024', 'reggaeton 2022 2023', 'reggaeton 2020 2021',
      'reggaeton 2018 2019', 'reggaeton hits 2015 2016 2017', 'reggaeton 2010s',
    ],
    'Latin Pop': [
      'latin pop 2024', 'latin pop 2022 2023', 'latin hits 2020 2021',
      'latin pop 2018 2019', 'musica latina 2015 2016 2017',
    ],
    'Bollywood': [
      'bollywood 2024', 'bollywood hits 2022 2023', 'bollywood 2020 2021',
      'bollywood 2018 2019', 'bollywood hits 2015 2016 2017',
      'bollywood 2010 2011 2012', 'bollywood classics 2000s',
    ],
    'Indie': [
      'indie pop 2024', 'indie hits 2022 2023', 'indie 2020 2021',
      'indie alternative 2018 2019', 'indie pop 2015 2016 2017',
    ],
    'Metal': [
      'heavy metal 2020s', 'metal rock 2010s', 'metal 2000s',
      'heavy metal classics 1990s', 'classic metal 1980s',
    ],
    'Jazz': ['jazz classics', 'smooth jazz', 'jazz hits', 'jazz standards popular'],
    'Reggae': ['reggae hits', 'reggae classics', 'reggae 2020s'],
    'Classics': [
      'greatest hits 1980s', 'greatest hits 1970s',
      'greatest hits 1960s', 'golden oldies',
    ],
    'Mix': [
      'top hits 2024', 'top hits 2023', 'chart hits 2022',
      'viral hits 2021', 'greatest hits popular', 'top hits 2020',
      'kpop hits 2023', 'reggaeton 2023', 'bollywood 2023',
      'hip hop 2023', 'rock hits 2022',
    ],
  };

  // ── iTunes search ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _search(String term,
      {int limit = 50, int offset = 0}) async {
    final encoded = Uri.encodeQueryComponent(term);
    final url = Uri.parse(
      '$_base/search?term=$encoded&media=music&entity=song'
          '&limit=$limit&offset=$offset&country=US',
    );

    try {
      final res = await http.get(url, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        debugPrint('iTunes ${res.statusCode}: ${res.body.substring(0, 100)}');
        return [];
      }
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(
        (data['results'] as List? ?? []).where((t) =>
        t != null && (t['previewUrl'] as String?) != null),
      );
    } catch (e) {
      debugPrint('iTunes search error: $e');
      return [];
    }
  }

  static const String _base = 'https://itunes.apple.com';

  // ── Convert iTunes track → Song ────────────────────────────────────────────

  Song? _trackToSong(Map<String, dynamic> t,
      {String? genre, String? language, int rank = 25}) {
    final previewUrl = t['previewUrl'] as String?;
    if (previewUrl == null) return null;

    final trackId   = (t['trackId'] as num?)?.toInt() ?? 0;
    final title     = t['trackName']      as String? ?? '';
    final artist    = t['artistName']     as String? ?? '';
    final album     = t['collectionName'] as String? ?? '';
    final albumArt  = (t['artworkUrl100'] as String? ?? '')
        .replaceAll('100x100', '640x640');
    final rawDate   = t['releaseDate']    as String? ?? '2000-01-01';
    final trackGenre = t['primaryGenreName'] as String? ?? genre ?? 'Pop';
    final year      = int.tryParse(rawDate.split('-').first) ?? 2000;
    final decade    = '${(year ~/ 10) * 10}s';
    final difficulty = _getDifficulty(rank, rawDate);

    return Song(
      id:            'itunes_$trackId',
      title:         title,
      artist:        artist,
      album:         album,
      audioUrl:      previewUrl,
      albumArtUrl:   albumArt,
      genre:         genre ?? trackGenre,
      language:      language ?? _guessLanguage(trackGenre),
      decade:        decade,
      difficulty:    difficulty,
      popularity:    (50 - rank).clamp(0, 100),
      silenceOffset: 0,
      hint1:         '${genre ?? trackGenre} song',
      hint2:         'Released in the $decade',
      hint3:         'By $artist',
      spotifyId:     'itunes_$trackId',
    );
  }

  // ── Difficulty: top search results = more well-known = easier ─────────────

  String _getDifficulty(int rank, String releaseDate) {
    final year = int.tryParse(releaseDate.split('-').first) ?? 2000;
    final age  = DateTime.now().year - year;
    // Combine search rank + era for rough difficulty estimate
    final score = (50 - rank).clamp(0, 50) + (age > 25 ? 20 : age > 10 ? 8 : 0);
    if (score >= 40) return 'easy';
    if (score >= 25) return 'medium';
    if (score >= 12) return 'hard';
    return 'hardcore';
  }

  String _guessLanguage(String genre) {
    if (['K-Pop'].contains(genre)) return 'Korean';
    if (['Bollywood'].contains(genre)) return 'Hindi';
    if (['Reggaeton', 'Latin Pop', 'Salsa'].contains(genre)) return 'Spanish';
    return 'English';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<List<Song>> fetchSongsForRoom({
    required String difficulty,
    String? genre,
    String? language,
    int count = 20,
  }) async {
    final resolvedGenre = (genre == null || genre.isEmpty || genre == 'Mix')
        ? 'Mix'
        : genre;

    final queries = List<String>.from(
      _queries[resolvedGenre] ?? _queries['Mix']!,
    )..shuffle(_rand);

    final List<Song> matched  = [];
    final List<Song> fallback = [];
    final Set<int> seen = {};

    for (final query in queries) {
      if (matched.length >= count && fallback.length >= count * 2) break;

      // Fetch 2 pages per query
      for (final offset in [0, 50]) {
        final tracks = await _search(query, limit: 50, offset: offset);

        for (var i = 0; i < tracks.length; i++) {
          final t  = tracks[i];
          final id = (t['trackId'] as num?)?.toInt() ?? 0;
          if (id == 0 || seen.contains(id)) continue;
          seen.add(id);

          final song = _trackToSong(t,
              genre: resolvedGenre == 'Mix' ? null : resolvedGenre,
              language: language,
              rank: i + offset);
          if (song == null) continue;

          fallback.add(song);
          if (song.difficulty == difficulty) matched.add(song);
        }
      }
    }

    // Prefer difficulty-matched songs; fall back to anything
    final pool = matched.length >= count ? matched : fallback;
    pool.shuffle(_rand);
    return pool.take(count).toList();
  }

  Future<List<Song>> fetchMixedSongs({int count = 20}) async {
    return fetchSongsForRoom(
      difficulty: 'medium',
      genre: 'Mix',
      count: count,
    );
  }
}