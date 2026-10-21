import 'package:flutter/material.dart';

// not built yet, just here so the navigation works
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  static const route = '/session';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Focus Session')),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
