import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class SongAudioService {
  final _player = AudioPlayer();
  int _silenceOffset = 0;
  Timer? _clipTimer;

  Future<void> loadSong(String audioUrl, {int silenceOffset = 0}) async {
    _silenceOffset = silenceOffset;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await _player.setUrl(audioUrl);
  }

  /// Plays only [seconds] worth of audio starting past silence offset.
  /// Non-blocking — schedules a hard stop via [stopClip] internally, so
  /// callers can also cancel it early (e.g. round ends before the clip
  /// naturally finishes) instead of being stuck awaiting a fixed delay.
  Future<void> playClip(int seconds) async {
    _clipTimer?.cancel();

    final start = Duration(seconds: _silenceOffset);
    await _player.seek(start);
    await _player.play();

    _clipTimer = Timer(Duration(seconds: seconds), () {
      if (_player.playing) _player.pause();
    });
  }

  /// Hard-stops any currently playing clip immediately and cancels the
  /// pending auto-stop timer, so a clip can never keep playing past when
  /// the round timer says it should have ended.
  Future<void> stopClip() async {
    _clipTimer?.cancel();
    _clipTimer = null;
    if (_player.playing) {
      await _player.pause();
    }
  }

  /// Play full song from silence offset at given volume (for reveal screens)
  Future<void> playFullAtVolume(double volume) async {
    _clipTimer?.cancel();
    _clipTimer = null;
    await _player.setVolume(volume);
    await _player.seek(Duration(seconds: _silenceOffset));
    await _player.play();
  }

  Future<void> stop() async {
    _clipTimer?.cancel();
    _clipTimer = null;
    await _player.stop();
  }

  Future<void> pause() async {
    _clipTimer?.cancel();
    _clipTimer = null;
    await _player.pause();
  }

  bool get isPlaying => _player.playing;

  void dispose() {
    _clipTimer?.cancel();
    _player.dispose();
  }
}