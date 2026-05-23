import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class SpotifyService {
  static const String _clientId =
  String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const String _clientSecret =
  String.fromEnvironment('SPOTIFY_CLIENT_SECRET');

  String? _accessToken;
  DateTime? _tokenExpiry;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String> _getToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    final creds = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic $creds',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    );

    if (res.statusCode != 200) {
      throw Exception('Spotify auth failed: ${res.body}');
    }

    final data = jsonDecode(res.body);
    _accessToken = data['access_token'] as String;
    _tokenExpiry =
        DateTime.now().add(Duration(seconds: data['expires_in'] as int));
    return _accessToken!;
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Returns a list of [Song]s filtered by [difficulty] and [genre]/[language].
  /// Difficulty is derived from Spotify's popularity score:
  ///   easy=75-100, medium=50-74, hard=25-49, hardcore=0-24
  /// Returns songs for a room. Tries difficulty filter first, falls back to any song with a preview.
  Future<List<Song>> fetchSongsForRoom({
    required String difficulty,
    String? genre,
    String? language,
    int count = 20,
  }) async {
    final token = await _getToken();
    final queries = _buildQueries(genre: genre, language: language);
    final List<Song> matched = [];
    final List<Song> fallback = [];
    final Set<String> seen = {};
    final rng = Random();
    queries.shuffle(rng);
    // Try each market until we have enough songs with previews
    outer:
    for (final market in _markets) {
      for (final query in queries.take(5)) {
        for (final offset in [0, 50, 100]) {
          final tracks = await _search(token, query, offset: offset, market: market);
          for (final track in tracks) {
            final id = track['id'] as String? ?? '';
            if (seen.contains(id)) continue;
            if ((track['preview_url'] as String?) == null) continue;
            seen.add(id);
            final song = _trackToSong(track, genre: genre, language: language);
            if (song == null) continue;
            fallback.add(song);
            if (song.difficulty == difficulty) matched.add(song);
          }
        }
      }
      if (fallback.length >= count) break outer;
    }
    final pool = matched.length >= count ? matched : fallback;
    pool.shuffle(rng);
    return pool.take(count).toList();
  }

  /// Fetch songs for "Mix" mode — all difficulties, all genres.
  Future<List<Song>> fetchMixedSongs({int count = 20}) async {
    final token = await _getToken();
    final rng = Random();
    final allQueries = _buildQueries()..shuffle(rng);
    final List<Song> results = [];
    final Set<String> seen = {};
    outer:
    for (final market in _markets) {
      for (final query in allQueries.take(6)) {
        for (final offset in [0, 50]) {
          final tracks = await _search(token, query, offset: offset, market: market);
          for (final track in tracks) {
            final id = track['id'] as String? ?? '';
            if (seen.contains(id)) continue;
            if ((track['preview_url'] as String?) == null) continue;
            seen.add(id);
            final song = _trackToSong(track);
            if (song != null) results.add(song);
          }
        }
      }
      if (results.length >= count) break outer;
    }
    results.shuffle(rng);
    return results.take(count).toList();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  // Add this constant at the top of the class:
  static const _markets = ['GB', 'AU', 'NZ', 'IE', 'CA', 'DE', 'FR', 'US'];
  Future<List<Map<String, dynamic>>> _search(
      String token,
      String query, {
        int offset = 0,
        String market = 'GB',
      }) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final url = Uri.parse(
      'https://api.spotify.com/v1/search'
          '?q=$encodedQuery&type=track&limit=50&offset=$offset&market=$market',
    );
    try {
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 429) {
        final wait = int.tryParse(res.headers['retry-after'] ?? '3') ?? 3;
        await Future.delayed(Duration(seconds: wait + 1));
        return _search(token, query, offset: offset, market: market);
      }
      if (res.statusCode != 200) {
        debugPrint('Spotify $market ${res.statusCode}: ${res.body}');
        return [];
      }
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(
        (data['tracks']?['items'] as List? ?? []).where((t) => t != null),
      );
    } catch (e) {
      debugPrint('Spotify search error: $e');
      return [];
    }
  }

  Song? _trackToSong(
      Map<String, dynamic> track, {
        String? genre,
        String? language,
      }) {
    final previewUrl = track['preview_url'] as String?;
    if (previewUrl == null) return null;

    final id = track['id'] as String? ?? '';
    final name = track['name'] as String? ?? '';
    final album = track['album'] as Map<String, dynamic>? ?? {};
    final artists = (track['artists'] as List? ?? [])
        .map((a) => (a as Map)['name'] as String? ?? '')
        .join(', ');
    final images = (album['images'] as List? ?? []);
    final albumArt = images.isNotEmpty
        ? ((images.firstWhere(
          (i) => (i['width'] as num?)?.toInt() == 640,
      orElse: () => images.first,
    ) as Map)['url'] as String? ??
        '')
        : '';
    final releaseDate = album['release_date'] as String? ?? '2000';
    final year = int.tryParse(releaseDate.split('-').first) ?? 2000;
    final decade = '${(year ~/ 10) * 10}s';
    final pop = (track['popularity'] as num?)?.toInt() ?? 0;
    final difficulty = _popularityToDifficulty(pop);

    return Song(
      id: 'spotify_$id',
      title: name,
      artist: artists,
      album: album['name'] as String? ?? '',
      audioUrl: previewUrl,
      albumArtUrl: albumArt,
      genre: genre ?? 'Mix',
      language: language ?? 'Mixed',
      decade: decade,
      difficulty: difficulty,
      popularity: pop,
      silenceOffset: 0,
      hint1: '${genre ?? "Music"} song',
      hint2: 'Released in the $decade',
      hint3: 'By ${artists.split(', ').first}',
      spotifyId: id,
    );
  }

  String _popularityToDifficulty(int pop) {
    if (pop >= 75) return 'easy';
    if (pop >= 50) return 'medium';
    if (pop >= 25) return 'hard';
    return 'hardcore';
  }

  /// Search queries per genre/language — simple keywords, no deprecated filters
  List<String> _buildQueries({String? genre, String? language}) {
    if (genre == null && language == null) {
      // Mix: broad popular searches
      return [
        'top hits 2024', 'top hits 2023', 'top hits 2022',
        'greatest hits popular', 'viral hits 2024',
        'kpop hits 2023', 'reggaeton 2023', 'bollywood 2023',
      ];
    }

    final Map<String, List<String>> byGenre = {
      'Pop': [
        'pop hits 2024', 'pop hits 2023', 'pop hits 2022',
        'pop hits 2020 2021', 'pop hits 2018 2019',
        'pop 2015 2016 2017', 'pop songs 2010s', 'pop 2000s', 'pop 1990s',
      ],
      'Hip-Hop': [
        'rap hits 2024', 'rap hits 2023', 'rap 2022',
        'hip hop 2020 2021', 'hip hop 2018 2019',
        'rap 2015 2016 2017', 'hip hop 2010 2011 2012',
        'rap classics 2000s', 'rap classics 1990s',
      ],
      'Rock': [
        'rock hits 2020s', 'rock hits 2010s', 'rock hits 2000s',
        'rock classics 1990s', 'rock classics 1980s', 'rock classics 1970s',
        'alternative rock 2020s', 'indie rock 2020s',
      ],
      'R&B': [
        'rnb hits 2024', 'rnb 2022 2023', 'rnb 2020 2021',
        'rnb 2018 2019', 'rnb 2015 2016 2017', 'soul hits 2010s',
        'rnb soul 2000s', 'soul classics 1990s',
      ],
      'Electronic': [
        'edm hits 2024', 'edm 2022 2023', 'dance music 2020 2021',
        'electronic dance 2018 2019', 'house music hits 2020s',
        'electronic music 2010s',
      ],
      'Country': [
        'country hits 2024', 'country 2022 2023', 'country 2020 2021',
        'country 2018 2019', 'country hits 2010s', 'country 2000s',
      ],
      'Indie': [
        'indie pop 2024', 'indie 2022 2023', 'indie 2020 2021',
        'indie alternative 2018 2019', 'indie pop 2015 2016 2017',
      ],
      'K-Pop': [
        'kpop 2024', 'kpop 2022 2023', 'kpop 2020 2021',
        'kpop 2018 2019', 'kpop 2016 2017', 'kpop 2013 2014 2015',
      ],
      'Reggaeton': [
        'reggaeton 2024', 'reggaeton 2022 2023', 'reggaeton 2020 2021',
        'reggaeton 2018 2019', 'reggaeton 2015 2016 2017', 'reggaeton 2010s',
      ],
      'Latin Pop': [
        'latin pop 2024', 'latin pop 2022 2023', 'musica latina 2020 2021',
        'latin hits 2018 2019', 'latin pop 2015 2016 2017',
      ],
      'Bollywood': [
        'bollywood 2024', 'bollywood 2022 2023', 'bollywood 2020 2021',
        'bollywood 2018 2019', 'bollywood 2015 2016 2017',
        'bollywood 2010 2011 2012', 'bollywood 2000s',
      ],
      'J-Pop': [
        'jpop 2023 2024', 'jpop 2021 2022', 'jpop 2019 2020',
        'anime songs popular', 'japanese pop hits',
      ],
      'Afrobeats': [
        'afrobeats 2024', 'afrobeats 2022 2023', 'afro 2020 2021',
        'afropop hits 2018 2019',
      ],
      'Metal': [
        'metal rock 2020s', 'heavy metal 2010s', 'metal classics 2000s',
        'heavy metal classics 1990s', 'metal 1980s',
      ],
      'Jazz': ['jazz classics popular', 'jazz hits', 'smooth jazz popular'],
      'Blues': ['blues classics popular', 'blues hits'],
      'Reggae': ['reggae hits popular', 'reggae classics'],
      'Gospel': ['gospel hits 2020s', 'christian music 2020s'],
      'Classics': [
        'greatest hits 1980s', 'greatest hits 1990s',
        'greatest hits 1970s', 'greatest hits 1960s',
      ],
      'Salsa': ['salsa hits popular', 'salsa clasica'],
      'Bossa Nova': ['bossa nova classic', 'bossa nova popular'],
    };

    final queries = byGenre[genre] ??
        ['${genre?.toLowerCase()} hits', '${language?.toLowerCase()} music hits'];
    return queries;
  }
}