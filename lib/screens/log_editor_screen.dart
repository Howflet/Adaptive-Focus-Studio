import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../helpers/format.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';

// No argument = add a manual entry. Pass a SessionLog to edit it.
class LogEditorScreen extends StatefulWidget {
  const LogEditorScreen({super.key});

  static const route = '/log-editor';

  @override
  State<LogEditorScreen> createState() => _LogEditorScreenState();
}

class _LogEditorScreenState extends State<LogEditorScreen> {
  final _db = DatabaseHelper.instance;
  final _minutes = TextEditingController();
  final _note = TextEditingController();
  SessionLog? _existing;
  List<FocusPreset> _presets = [];
  FocusPreset? _preset;
  DateTime _date = DateTime.now();
  bool _loadedArgs = false;
  bool _loading = true;
  bool _saving = false;
  String? _minutesError;
  String? _dateError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedArgs) return;
    _loadedArgs = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is SessionLog) {
      _existing = arg;
      _date = DateTime.parse(arg.startedAt);
      _minutes.text = (arg.completedSeconds ~/ 60).toString();
      _note.text = arg.note ?? '';
    }
    _loadPresets();
  }

  @override
  void dispose() {
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final presets = await _db.getPresets();
      if (!mounted) return;
      setState(() {
        _presets = presets;
        if (_existing != null) {
          _preset = presets.where((p) => p.id == _existing!.presetId).firstOrNull;
        } else if (presets.isNotEmpty) {
          _preset = presets.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        // keep the time of day if it's the same day
        _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
        _dateError = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _preset == null) return;

    final text = _minutes.text.trim();
    final mins = int.tryParse(text);
    if (mins == null || mins < 0) {
      setState(() => _minutesError = 'Enter minutes, 0 or more');
      return;
    }

    // if the minutes weren't touched, keep the exact seconds from the timer
    var seconds = mins * 60;
    final old = _existing;
    if (old != null && mins == old.completedSeconds ~/ 60) {
      seconds = old.completedSeconds;
    }

    var started = _date;
    if (old == null) {
      // today = right now, other days = noon
      final now = DateTime.now();
      final today = _date.year == now.year && _date.month == now.month && _date.day == now.day;
      started = today ? now : DateTime(_date.year, _date.month, _date.day, 12);
    }

    final note = _note.text.trim();
    final log = SessionLog(
      id: old?.id,
      presetId: old?.presetId ?? _preset!.id!,
      startedAt: started.toIso8601String(),
      plannedSecondsSnapshot: old?.plannedSecondsSnapshot ?? _preset!.plannedSeconds,
      completedSeconds: seconds,
      moodTagSnapshot: old?.moodTagSnapshot ?? _preset!.moodTag,
      status: old?.status ?? 'finished',
      source: old?.source ?? 'manual',
      note: note.isEmpty ? null : note,
    );

    final error = log.validate();
    if (error != null) {
      setState(() {
        _minutesError = null;
        _dateError = error;
      });
      return;
    }

    setState(() {
      _minutesError = null;
      _dateError = null;
      _saving = true;
    });
    try {
      if (old == null) {
        await _db.insertLog(log);
      } else {
        await _db.updateLog(log);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Add Manual Entry' : 'Edit Session'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_preset == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_existing == null
                        ? 'Make a preset first, then you can add a session for it.'
                        : 'That preset is gone.'),
                  ),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_existing == null)
          DropdownButtonFormField<FocusPreset>(
            initialValue: _preset,
            decoration: const InputDecoration(
              labelText: 'Preset *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final p in _presets) DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => setState(() => _preset = v ?? _preset),
          )
        else
          Text('Preset: ${_preset!.label}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Date: ${shortDate(_date)}'),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _pickDate, child: const Text('Change')),
          ],
        ),
        if (_dateError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_dateError!, style: TextStyle(color: Colors.red.shade800, fontSize: 12)),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _minutes,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Completed minutes *',
            border: const OutlineInputBorder(),
            errorText: _minutesError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
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
    );
  }
}
