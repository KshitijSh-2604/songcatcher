import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class SongAudioService {
  final _player = AudioPlayer();
  int _silenceOffset = 0;

  Future<void> loadSong(String audioUrl, {int silenceOffset = 0}) async {
    _silenceOffset = silenceOffset;

    // Configure audio session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await _player.setUrl(audioUrl);
  }

  /// Plays only [seconds] worth of audio starting past silence offset
  Future<void> playClip(int seconds) async {
    final start = Duration(seconds: _silenceOffset);
    final end = Duration(seconds: _silenceOffset + seconds);

    await _player.seek(start);
    await _player.play();

    // Stop after clip duration
    await Future.delayed(end - start);
    if (_player.playing) await _player.stop();
  }

  /// Play full song from silence offset at given volume (for reveal screens)
  Future<void> playFullAtVolume(double volume) async {
    await _player.setVolume(volume);
    await _player.seek(Duration(seconds: _silenceOffset));
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  bool get isPlaying => _player.playing;

  void dispose() {
    _player.dispose();
  }
}