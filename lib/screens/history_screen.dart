import 'package:flutter/material.dart';

// not built yet, just here so the navigation works
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const route = '/history';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
