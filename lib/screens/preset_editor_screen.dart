import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../data/settings_store.dart';
import '../helpers/session_scout.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import '../widgets/scout_card.dart';

// Pass a FocusPreset as the route argument to edit it, nothing to create new.
class PresetEditorScreen extends StatefulWidget {
  const PresetEditorScreen({super.key});

  static const route = '/editor';

  @override
  State<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

class _PresetEditorScreenState extends State<PresetEditorScreen> {
  final _label = TextEditingController();
  String _mood = moodTags.first;
  double _minutes = 25;
  FocusPreset? _existing;
  bool _loadedArgs = false;
  bool _saving = false;
  String? _labelError;
  List<SessionLog> _logs = [];
  bool _scoutDismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedArgs) return;
    _loadedArgs = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is FocusPreset) {
      _existing = arg;
      _label.text = arg.label;
      _mood = arg.moodTag;
      _minutes = arg.plannedSeconds / 60;
    } else {
      // new preset starts at the default from settings
      _minutes = SettingsStore.instance.current.value.defaultDurationMinutes.toDouble();
    }
    _loadLogs();
  }

  // Session Scout reads the saved sessions
  Future<void> _loadLogs() async {
    try {
      final rows = await DatabaseHelper.instance.getLogs();
      if (!mounted) return;
      setState(() => _logs = [for (final r in rows) r.log]);
    } catch (e) {
      // no history means the card just says not enough history
    }
  }

  // only fills the slider, nothing is saved until Save is pressed
  void _applySuggestion(int minutes) {
    setState(() => _minutes = minutes.toDouble());
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final preset = FocusPreset(
      id: _existing?.id,
      label: _label.text,
      moodTag: _mood,
      plannedSeconds: _minutes.round() * 60,
    );

    final error = preset.validate();
    if (error != null) {
      setState(() => _labelError = error);
      return;
    }
    setState(() {
      _labelError = null;
      _saving = true;
    });

    try {
      if (_existing == null) {
        await DatabaseHelper.instance.insertPreset(preset);
      } else {
        await DatabaseHelper.instance.updatePreset(preset);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      // keep what they typed
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New Preset' : 'Edit Preset'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _label,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: 'Task label *',
              hintText: 'Chem reading',
              border: const OutlineInputBorder(),
              errorText: _labelError,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _mood,
            decoration: const InputDecoration(
              labelText: 'Mood tag *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in moodTags) DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() {
              _mood = v ?? _mood;
              _scoutDismissed = false;
            }),
          ),
          const SizedBox(height: 16),
          const Text('Planned duration (minutes)'),
          Slider(
            value: _minutes,
            min: 5,
            max: 120,
            divisions: 23,
            label: '${_minutes.round()} min',
            onChanged: (v) => setState(() => _minutes = v),
          ),
          Center(
            child: Text('${_minutes.round()} min',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (!_scoutDismissed) ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final result = suggestDuration(_logs, _mood);
              return ScoutCard(
                result: result,
                onApply: () => _applySuggestion(result.minutes!),
                onDismiss: () => setState(() => _scoutDismissed = true),
              );
            }),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
