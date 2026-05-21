import 'dart:convert';
import 'package:http/http.dart' as http;

class SpotifyService {
  // Pass credentials via --dart-define at build time (see below)
  static const _clientId =
  String.fromEnvironment('SPOTIFY_CLIENT_ID', defaultValue: '');
  static const _clientSecret =
  String.fromEnvironment('SPOTIFY_CLIENT_SECRET', defaultValue: '');

  static const _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const _apiUrl   = 'https://api.spotify.com/v1';

  String? _token;
  DateTime? _tokenExpiry;

  // ── Get access token ─────────────────────────────────────────────────────

  Future<String> _getToken() async {
    if (_token != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _token!;
    }

    final creds = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final res = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $creds',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    );

    if (res.statusCode != 200) {
      throw Exception('Spotify auth failed: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['access_token'] as String;
    _tokenExpiry = DateTime.now()
        .add(Duration(seconds: (data['expires_in'] as int) - 60));
    return _token!;
  }

  // ── Fetch tracks from a playlist ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPlaylistTracks(
      String playlistId) async {
    final token = await _getToken();
    final tracks = <Map<String, dynamic>>[];

    String? url =
        '$_apiUrl/playlists/$playlistId/tracks?limit=100&market=US';

    while (url != null) {
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) break;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['items'] as List;

      for (final item in items) {
        final track = item['track'] as Map<String, dynamic>?;
        if (track == null || track['preview_url'] == null) continue;
        tracks.add(track);
      }

      url = data['next'] as String?;
    }

    return tracks;
  }

  // ── Seed helper — returns song maps ready for Firestore ──────────────────

  Map<String, dynamic> trackToSongDoc(
      Map<String, dynamic> track, String language, String genre) {
    final album = track['album'] as Map<String, dynamic>;
    final images = album['images'] as List;
    final albumArt = images.isNotEmpty
        ? (images.firstWhere(
          (i) => (i['width'] as int?) == 640,
      orElse: () => images.first,
    )['url'] as String?)
        : null;

    final releaseDate = album['release_date'] as String? ?? '2000';
    final year = int.tryParse(releaseDate.substring(0, 4)) ?? 2000;
    final decade = '${(year ~/ 10) * 10}s';

    final artists = (track['artists'] as List)
        .map((a) => a['name'] as String)
        .join(', ');

    return {
      'title': track['name'] as String,
      'artist': artists,
      'album': album['name'] as String,
      'audioUrl': track['preview_url'] as String,
      'albumArtUrl': albumArt,
      'language': language,
      'genre': genre,
      'decade': decade,
      'silenceOffset': 0,
      'spotifyId': track['id'] as String,
    };
  }
}