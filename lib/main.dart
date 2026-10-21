import 'package:flutter/material.dart';

import 'screens/history_screen.dart';
import 'screens/log_editor_screen.dart';
import 'screens/preset_editor_screen.dart';
import 'screens/presets_screen.dart';
import 'screens/session_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const FocusApp());
}

class FocusApp extends StatelessWidget {
  const FocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Focus Studio',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF444444),
          secondary: Color(0xFF444444),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      initialRoute: PresetsScreen.route,
      routes: {
        PresetsScreen.route: (_) => const PresetsScreen(),
        PresetEditorScreen.route: (_) => const PresetEditorScreen(),
        SessionScreen.route: (_) => const SessionScreen(),
        HistoryScreen.route: (_) => const HistoryScreen(),
        LogEditorScreen.route: (_) => const LogEditorScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
      },
    );
  }
}
