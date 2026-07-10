import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

/// Uses Apple's iTunes Search API — no account, no API key, completely free.
/// Endpoint: https://itunes.apple.com/search
/// Returns 30-second M4A preview URLs for ~95% of tracks.
///
/// Bollywood-only per app scope — genre is fixed, so queries are organized
/// by decade instead of by genre, and callers filter by yearFrom/yearTo.
/// Difficulty is not host-selectable — it's derived per song and used to
/// scale points, with the most obscure tier excluded entirely.
class ItunesService {
  final _rand = Random();

  static const String _base = 'https://itunes.apple.com';

  static const Map<int, List<String>> _decadeQueries = {
    1950: ['bollywood classics 1950s', 'old hindi songs 1950s', 'hindi film songs 1950s'],
    1960: ['bollywood classics 1960s', 'old hindi songs 1960s', 'hindi film songs 1960s'],
    1970: ['bollywood classics 1970s', 'old hindi songs 1970s', 'hindi film songs 1970s'],
    1980: ['bollywood classics 1980s', 'old hindi songs 1980s', 'hindi film songs 1980s'],
    1990: ['bollywood hits 1990s', 'hindi songs 1990s', 'bollywood 90s'],
    2000: ['bollywood hits 2000s', 'hindi songs 2000 2001 2002', 'bollywood 2003 2004 2005', 'bollywood 2006 2007 2008 2009'],
    2010: ['bollywood hits 2010 2011 2012', 'bollywood 2013 2014 2015', 'bollywood 2016 2017', 'bollywood hits 2018 2019'],
    2020: ['bollywood 2020 2021', 'bollywood hits 2022 2023', 'bollywood 2024'],
  };

  // ── iTunes search ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _search(String term, {int limit = 50, int offset = 0}) async {
    final encoded = Uri.encodeQueryComponent(term);
    final url = Uri.parse(
      '$_base/search?term=$encoded&media=music&entity=song'
          '&limit=$limit&offset=$offset&country=IN',
    );

    try {
      final res = await http.get(url, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        debugPrint('iTunes ${res.statusCode}: ${res.body.substring(0, min(100, res.body.length))}');
        return [];
      }
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(
        (data['results'] as List? ?? []).where((t) => t != null && (t['previewUrl'] as String?) != null),
      );
    } catch (e) {
      debugPrint('iTunes search error: $e');
      return [];
    }
  }

  // ── Convert iTunes track → Song ────────────────────────────────────────────

  Song? _trackToSong(Map<String, dynamic> t, {int rank = 25}) {
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
    final difficulty = _getDifficulty(rank, rawDate);

    return Song(
      id: 'itunes_$trackId',
      title: title,
      artist: artist,
      album: album,
      audioUrl: previewUrl,
      albumArtUrl: albumArt,
      genre: 'Bollywood',
      language: 'Hindi',
      decade: decade,
      difficulty: difficulty,
      popularity: (50 - rank).clamp(0, 100),
      silenceOffset: 0,
      hint1: 'Bollywood song',
      hint2: 'Released in the $decade',
      hint3: 'By $artist',
      spotifyId: 'itunes_$trackId',
      year: year,
    );
  }

  // ── Difficulty: top search results = more well-known = easier ─────────────

  String _getDifficulty(int rank, String releaseDate) {
    final year = int.tryParse(releaseDate.split('-').first) ?? 2000;
    final age = DateTime.now().year - year;
    final score = (50 - rank).clamp(0, 50) + (age > 25 ? 20 : age > 10 ? 8 : 0);
    if (score >= 40) return 'easy';
    if (score >= 25) return 'medium';
    if (score >= 12) return 'hard';
    return 'hardcore';
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches Bollywood songs whose release year falls within [yearFrom, yearTo].
  /// Difficulty is not chosen by the host — each song's difficulty is derived
  /// from how well-known it is (search rank + era), and the pool here
  /// deliberately excludes the "hardcore"/most-obscure tier so rounds never
  /// hinge on a track nobody could reasonably know. Difficulty is instead
  /// used later to scale how many points a correct guess is worth.
  Future<List<Song>> fetchSongsForRoom({
    required String genre, // kept for call-site compatibility; always Bollywood
    required int yearFrom,
    required int yearTo,
    int count = 20,
  }) async {
    final decadeStarts = _decadeQueries.keys.where((d) => d + 9 >= yearFrom && d <= yearTo).toList()..sort();

    final queries = <String>[];
    for (final decade in decadeStarts) {
      queries.addAll(_decadeQueries[decade]!);
    }
    if (queries.isEmpty) queries.addAll(_decadeQueries[2000]!);
    queries.shuffle(_rand);

    final List<Song> pool = [];
    final Set<int> seen = {};

    for (final query in queries) {
      if (pool.length >= count * 3) break;

      for (final offset in [0, 50]) {
        final tracks = await _search(query, limit: 50, offset: offset);

        for (var i = 0; i < tracks.length; i++) {
          final t = tracks[i];
          final id = (t['trackId'] as num?)?.toInt() ?? 0;
          if (id == 0 || seen.contains(id)) continue;
          seen.add(id);

          final song = _trackToSong(t, rank: i + offset);
          if (song == null) continue;

          // Enforce the year range strictly — iTunes search terms are a
          // coarse filter only; some off-decade results always leak in.
          if (song.year < yearFrom || song.year > yearTo) continue;

          // Skip the most obscure tier entirely — keep guesses fair.
          if (song.difficulty == 'hardcore') continue;

          pool.add(song);
        }
      }
    }

    // Mix difficulties so rounds vary, but weight toward easier/medium songs
    // so a randomized game doesn't skew too hard.
    final easy = pool.where((s) => s.difficulty == 'easy').toList()..shuffle(_rand);
    final medium = pool.where((s) => s.difficulty == 'medium').toList()..shuffle(_rand);
    final hard = pool.where((s) => s.difficulty == 'hard').toList()..shuffle(_rand);

    final mixed = <Song>[];
    final easyCount = (count * 0.45).ceil();
    final mediumCount = (count * 0.35).ceil();
    final hardCount = count - easyCount - mediumCount;

    mixed.addAll(easy.take(easyCount));
    mixed.addAll(medium.take(mediumCount));
    mixed.addAll(hard.take(hardCount));

    if (mixed.length < count) {
      final rest = pool.where((s) => !mixed.contains(s)).toList()..shuffle(_rand);
      mixed.addAll(rest.take(count - mixed.length));
    }

    mixed.shuffle(_rand);
    return mixed.take(count).toList();
  }
}