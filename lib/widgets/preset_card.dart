import 'package:flutter/material.dart';

import '../models/focus_preset.dart';

class PresetCard extends StatelessWidget {
  final FocusPreset preset;
  final VoidCallback onTap;

  const PresetCard({super.key, required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final minutes = preset.plannedSeconds ~/ 60;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey.shade700),
      ),
      child: ListTile(
        title: Text(preset.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${preset.moodTag} · $minutes min'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
