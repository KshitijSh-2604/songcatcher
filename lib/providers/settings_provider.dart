import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState(
    sfxEnabled: _prefs.getBool('sfxEnabled') ?? true,
    hapticsEnabled: _prefs.getBool('hapticsEnabled') ?? true,
  ));

  void toggleSfx() {
    state = state.copyWith(sfxEnabled: !state.sfxEnabled);
    _prefs.setBool('sfxEnabled', state.sfxEnabled);
  }

  void toggleHaptics() {
    state = state.copyWith(hapticsEnabled: !state.hapticsEnabled);
    _prefs.setBool('hapticsEnabled', state.hapticsEnabled);
  }
}

class SettingsState {
  final bool sfxEnabled;
  final bool hapticsEnabled;

  SettingsState({required this.sfxEnabled, required this.hapticsEnabled});

  SettingsState copyWith({bool? sfxEnabled, bool? hapticsEnabled}) {
    return SettingsState(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return SettingsNotifier(prefs);
});
