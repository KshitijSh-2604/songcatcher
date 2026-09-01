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

  Song? _trackToSong(Map<String, dynamic> t, {int rank = 25, String genre = 'Mixed', int? yearFrom, int? yearTo}) {
    final previewUrl = t['previewUrl'] as String?;
    if (previewUrl == null) return null;

    final title = t['trackName'] as String? ?? '';
    final album = t['collectionName'] as String? ?? '';
    final artist = t['artistName'] as String? ?? '';

    // 🚫 1. Blacklist unwanted versions
    final blacklist = [
      'mix', 'lofi', 'slowed', 'reverbed', 'reverb', 'acoustic', 'remix', 
      'mashup', 'tribute', 'cover', 'instrumental', 'karaoke', 'live', 
      'version', 'edit', 're-recorded', 'remaster', 'remastered', 'hits',
      'radio edit', 'extended mix', 'club mix', 'unplugged', 'demo', 'bollywood'
    ];
    
    final searchable = '$title $album'.toLowerCase();
    if (blacklist.any((word) => searchable.contains(word))) {
      return null;
    }

    // 🗓️ 2. Smart Year Filtering (Handle compilations)
    final rawDate = t['releaseDate'] as String? ?? '2000-01-01';
    int year = int.tryParse(rawDate.split('-').first) ?? 2000;
    
    // If the album title explicitly mentions an older era (e.g., "1950s", "90s")
    // but the release year is modern, it's likely a compilation.
    final eraMatch = RegExp(r'(19|20)\d{2}').firstMatch(album);
    if (eraMatch != null) {
      final albumYear = int.tryParse(eraMatch.group(0)!);
      if (albumYear != null && albumYear < year) {
        year = albumYear; // Trust the era mentioned in album title over release date
      }
    }

    // Secondary check: If searching for modern songs, skip "Classics" or "Retro" albums
    if (yearTo != null && yearTo >= 2010) {
       final retroKeywords = ['classic', 'retro', 'vintage', 'oldies', 'gold', 'golden', '1940', '1950', '1960', '1970', '1980', '1990'];
       if (retroKeywords.any((k) => album.toLowerCase().contains(k))) return null;
    }

    if (yearFrom != null && year < yearFrom) return null;
    if (yearTo != null && year > yearTo) return null;

    final trackId = (t['trackId'] as num?)?.toInt() ?? 0;
    final albumArt = (t['artworkUrl100'] as String? ?? '').replaceAll('100x100', '640x640');
    final decade = '${(year ~/ 10) * 10}s';
    
    final isHindi = t['primaryGenreName'] == 'Bollywood' || artist.toLowerCase().contains('arijit') || title.toLowerCase().contains('dil');
    final isPunjabi = genre == 'Punjabi' || artist.toLowerCase().contains('sidhu') || artist.toLowerCase().contains('diljit');

    return Song(
      id: 'itunes_$trackId',
      title: title,
      artist: artist,
      album: album,
      audioUrl: previewUrl,
      albumArtUrl: albumArt,
      genre: genre,
      language: isHindi ? 'Hindi' : (isPunjabi ? 'Punjabi' : 'English'),
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

    // "Now" (2030 in UI) means current year
    final actualYearTo = yearTo >= 2030 ? DateTime.now().year : yearTo;
    final actualYearFrom = yearFrom >= 2030 ? DateTime.now().year : yearFrom;

    if (genre == 'Bollywood') {
      queries.addAll([
        'bollywood hits', 'hindi film songs', 'bollywood classics', 
        'latest hindi songs', 'arijit singh hits', 'shreya ghoshal best',
        '90s bollywood', '2000s hindi hits'
      ]);
      country = 'IN';
    } else if (genre == 'English') {
      queries.addAll([
        'english hits', 'pop hits', 'rock essentials', 'top songs us', 
        'billboard hot 100', '90s pop', '80s rock'
      ]);
      country = 'US';
    } else if (genre == 'International') {
      queries.addAll([
        'global hits', 'international top songs', 'world music hits', 
        'latin pop hits', 'k-pop essentials'
      ]);
      country = 'US';
    } else if (genre == 'Punjabi') {
      queries.addAll([
        'punjabi hits', 'punjabi pop', 'bhangra essentials', 
        'sidhu moose wala best', 'diljit dosanjh hits', 'ap dhillon best',
        'latest punjabi songs'
      ]);
      country = 'IN';
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
      if (pool.length >= count * 15) break; // 🚀 Even larger pool for better variety
      
      // 🎲 Offset results randomly to avoid repetition across games
      final randomOffset = _rand.nextInt(400); 
      final tracks = await _search(query, limit: 100, offset: randomOffset, country: country);
      
      for (var i = 0; i < tracks.length; i++) {
        final t = tracks[i];
        final id = (t['trackId'] as num?)?.toInt() ?? 0;
        if (id == 0 || seen.contains(id)) continue;
        
        final song = _trackToSong(
          t, 
          rank: i, 
          genre: genre, 
          yearFrom: actualYearFrom, 
          yearTo: actualYearTo,
        );
        
        if (song == null) continue;
        seen.add(id);
        pool.add(song);
      }
    }

    if (pool.isEmpty) return [];
    
    pool.shuffle(_rand);
    // Return a random selection from the pool instead of just the first 'count'
    return pool.take(count).toList();
  }
}
