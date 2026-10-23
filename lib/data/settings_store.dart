import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final int defaultDurationMinutes;
  final bool reduceMotion;
  final bool soundEnabled;
  final bool confirmBeforeReset;

  const AppSettings({
    this.defaultDurationMinutes = 25,
    this.reduceMotion = false,
    this.soundEnabled = false,
    this.confirmBeforeReset = true,
  });

  AppSettings copyWith({
    int? defaultDurationMinutes,
    bool? reduceMotion,
    bool? soundEnabled,
    bool? confirmBeforeReset,
  }) =>
      AppSettings(
        defaultDurationMinutes: defaultDurationMinutes ?? this.defaultDurationMinutes,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        confirmBeforeReset: confirmBeforeReset ?? this.confirmBeforeReset,
      );
}

// Settings live in SharedPreferences (simple key/value, no need for sqlite).
// `current` is what the rest of the app listens to.
class SettingsStore {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const keyDuration = 'defaultDurationMinutes';
  static const keyReduceMotion = 'reduceMotion';
  static const keySound = 'soundEnabled';
  static const keyConfirmReset = 'confirmBeforeReset';

  final ValueNotifier<AppSettings> current = ValueNotifier(const AppSettings());

  Future<AppSettings> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      const d = AppSettings();
      var minutes = p.getInt(keyDuration) ?? d.defaultDurationMinutes;
      // don't trust whatever is stored, keep it inside the slider range
      if (minutes < 5 || minutes > 120) minutes = d.defaultDurationMinutes;
      current.value = AppSettings(
        defaultDurationMinutes: minutes,
        reduceMotion: p.getBool(keyReduceMotion) ?? d.reduceMotion,
        soundEnabled: p.getBool(keySound) ?? d.soundEnabled,
        confirmBeforeReset: p.getBool(keyConfirmReset) ?? d.confirmBeforeReset,
      );
    } catch (e) {
      // if prefs can't be read just use the defaults
      current.value = const AppSettings();
    }
    return current.value;
  }

  // updates the app right away, then writes to disk. Returns false if the write failed.
  Future<bool> save(AppSettings s) async {
    current.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(keyDuration, s.defaultDurationMinutes);
      await p.setBool(keyReduceMotion, s.reduceMotion);
      await p.setBool(keySound, s.soundEnabled);
      await p.setBool(keyConfirmReset, s.confirmBeforeReset);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetToDefaults() => save(const AppSettings());
}
