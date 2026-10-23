import 'package:flutter/material.dart';

import '../data/settings_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = SettingsStore.instance;
  AppSettings _s = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _store.load();
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
  }

  // every change saves right away
  Future<void> _change(AppSettings s) async {
    setState(() => _s = s);
    final ok = await _store.save(s);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't save settings.")));
    }
  }

  Future<void> _reset() async {
    final ok = await _store.resetToDefaults();
    if (!mounted) return;
    setState(() => _s = _store.current.value);
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't save settings.")));
    }
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SwitchListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Default duration (minutes)'),
                Slider(
                  value: _s.defaultDurationMinutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '${_s.defaultDurationMinutes} min',
                  onChanged: (v) => setState(
                      () => _s = _s.copyWith(defaultDurationMinutes: v.round())),
                  // only write to disk when they let go
                  onChangeEnd: (v) =>
                      _change(_s.copyWith(defaultDurationMinutes: v.round())),
                ),
                Center(
                  child: Text('${_s.defaultDurationMinutes} min',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                _toggle('Reduce motion', _s.reduceMotion,
                    (v) => _change(_s.copyWith(reduceMotion: v))),
                _toggle('Sound effects', _s.soundEnabled,
                    (v) => _change(_s.copyWith(soundEnabled: v))),
                _toggle('Confirm before reset', _s.confirmBeforeReset,
                    (v) => _change(_s.copyWith(confirmBeforeReset: v))),
                const SizedBox(height: 8),
                Text(
                  'Saved on this phone with SharedPreferences.\nWorks offline: nothing leaves the device.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset settings to defaults'),
                ),
              ],
            ),
    );
  }
}
