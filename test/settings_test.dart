import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adaptive_focus_studio/data/settings_store.dart';
import 'package:adaptive_focus_studio/main.dart';
import 'package:adaptive_focus_studio/screens/settings_screen.dart';

void main() {
  final store = SettingsStore.instance;

  // pretend the app was closed and opened again
  Future<AppSettings> restart() async {
    store.current.value = const AppSettings();
    return store.load();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store.current.value = const AppSettings();
  });

  test('defaults match the proposal', () async {
    final s = await store.load();
    expect(s.defaultDurationMinutes, 25);
    expect(s.reduceMotion, false);
    expect(s.soundEnabled, false);
    expect(s.confirmBeforeReset, true);
  });

  test('saved settings survive a restart', () async {
    await store.save(const AppSettings(
      defaultDurationMinutes: 40,
      reduceMotion: true,
      soundEnabled: true,
      confirmBeforeReset: false,
    ));
    final s = await restart();
    expect(s.defaultDurationMinutes, 40);
    expect(s.reduceMotion, true);
    expect(s.soundEnabled, true);
    expect(s.confirmBeforeReset, false);
  });

  test('a stored duration outside 5-120 falls back to the default', () async {
    SharedPreferences.setMockInitialValues({SettingsStore.keyDuration: 500});
    final s = await store.load();
    expect(s.defaultDurationMinutes, 25);
  });

  test('reset puts everything back', () async {
    await store.save(const AppSettings(defaultDurationMinutes: 60, soundEnabled: true));
    await store.resetToDefaults();
    final s = await restart();
    expect(s.defaultDurationMinutes, 25);
    expect(s.soundEnabled, false);
  });

  testWidgets('toggling a switch saves it right away', (t) async {
    await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Sound effects'));
    await t.pumpAndSettle();
    expect(store.current.value.soundEnabled, true);
    final s = await t.runAsync(restart);
    expect(s!.soundEnabled, true);
  });

  testWidgets('reset button on the settings screen restores defaults', (t) async {
    await store.save(const AppSettings(defaultDurationMinutes: 90, reduceMotion: true));
    await t.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await t.pumpAndSettle();
    expect(find.text('90 min'), findsOneWidget);
    await t.tap(find.text('Reset settings to defaults'));
    await t.pumpAndSettle();
    expect(find.text('25 min'), findsOneWidget);
    expect(store.current.value.reduceMotion, false);
  });

  testWidgets('reduce motion turns off the page transition', (t) async {
    store.current.value = const AppSettings(reduceMotion: true);
    await t.pumpWidget(const FocusApp());
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.pageTransitionsTheme.builders.length, 2);
  });
}
