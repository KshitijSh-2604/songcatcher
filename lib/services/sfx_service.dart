import 'package:just_audio/just_audio.dart';

class SfxService {
  static final SfxService _instance = SfxService._internal();
  factory SfxService() => _instance;
  SfxService._internal();

  final _player = AudioPlayer();
  bool _enabled = true;

  void setEnabled(bool value) => _enabled = value;

  Future<void> playCorrect() async {
    if (!_enabled) return;
    await _playAsset('assets/sfx/correct.mp3');
  }

  Future<void> playCountdown() async {
    if (!_enabled) return;
    await _playAsset('assets/sfx/tick.mp3');
  }

  Future<void> playInvite() async {
    if (!_enabled) return;
    await _playAsset('assets/sfx/invite.mp3');
  }

  Future<void> _playAsset(String path) async {
    try {
      await _player.setAsset(path);
      await _player.play();
    } catch (e) {
      // Silently fail if assets missing
    }
  }

  void dispose() {
    _player.dispose();
  }
}
