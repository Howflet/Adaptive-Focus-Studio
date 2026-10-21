import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../models/focus_preset.dart';
import '../widgets/empty_state.dart';
import '../widgets/mood_chip.dart';
import '../widgets/preset_card.dart';
import '../widgets/stat_tile.dart';
import 'history_screen.dart';
import 'preset_editor_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  static const route = '/';

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  final _db = DatabaseHelper.instance;
  List<FocusPreset> _presets = [];
  String? _mood; // null means All
  String _average = 'No sessions yet.';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // always reload from the database, don't keep our own copy in sync
  Future<void> _load() async {
    try {
      final presets = await _db.getPresets(mood: _mood);
      final avg = await _db.getAverageCompleted();
      if (!mounted) return;
      setState(() {
        _presets = presets;
        _average = avg.averageMinutes == null
            ? 'No sessions yet.'
            : '${avg.averageMinutes!.round()} min (from ${avg.count} sessions)';
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load presets.";
      });
    }
  }

  Future<void> _go(String route, {Object? args}) async {
    await Navigator.pushNamed(context, route, arguments: args);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Presets'),
        actions: [
          TextButton(
            onPressed: () => _go(SettingsScreen.route),
            child: const Text('Settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatTile(title: 'Avg completed session', value: _average),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Filter by mood: '),
                  MoodChip(
                    label: 'All',
                    selected: _mood == null,
                    onTap: () {
                      _mood = null;
                      _load();
                    },
                  ),
                  for (final m in moodTags)
                    MoodChip(
                      label: m,
                      selected: _mood == m,
                      onTap: () {
                        _mood = m;
                        _load();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () => _go(HistoryScreen.route),
                  child: const Text('History'),
                ),
                FloatingActionButton(
                  onPressed: () => _go(PresetEditorScreen.route),
                  tooltip: 'New preset',
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_presets.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: EmptyState(
          message: _mood == null
              ? 'No presets yet. Tap + to create one.'
              : 'No $_mood presets.',
        ),
      );
    }
    return ListView(
      children: [
        for (final p in _presets)
          PresetCard(
            preset: p,
            onTap: () => _go(SessionScreen.route, args: p.id),
          ),
      ],
    );
  }
}
