import 'package:flutter/material.dart';

// not built yet, just here so the navigation works
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
