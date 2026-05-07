import 'package:just_audio/just_audio.dart';

class SongAudioService {
  final _player = AudioPlayer();
  Duration? _songDuration;

  Future<void> loadSong(String url) async {
    await _player.setUrl(url);
    _songDuration = _player.duration;
  }

  /// Play only [seconds] seconds from the start
  Future<void> playClip(int seconds) async {
    await _player.seek(Duration.zero);
    await _player.play();

    await Future.delayed(Duration(seconds: seconds), () async {
      await _player.pause();
    });
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Stream<Duration> get positionStream => _player.positionStream;
  bool get isPlaying => _player.playing;
}