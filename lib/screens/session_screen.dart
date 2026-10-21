import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../helpers/clock.dart';
import '../helpers/session_timer.dart';
import '../models/focus_preset.dart';
import '../models/session_log.dart';
import 'preset_editor_screen.dart';

// Route argument is the preset id (an int).
class SessionScreen extends StatefulWidget {
  final Clock clock;

  const SessionScreen({super.key, this.clock = const Clock()});

  static const route = '/session';

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _db = DatabaseHelper.instance;
  FocusPreset? _preset;
  SessionTimer? _timer;
  Timer? _ticker;
  bool _loadedArgs = false;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedArgs) return;
    _loadedArgs = true;
    final id = ModalRoute.of(context)?.settings.arguments;
    if (id is int) {
      _loadPreset(id);
    } else {
      _error = 'No preset picked.';
    }
  }

  @override
  void dispose() {
    _ticker?.cancel(); // don't leave the timer running after leaving the screen
    super.dispose();
  }

  Future<void> _loadPreset(int id) async {
    try {
      final p = await _db.getPreset(id);
      if (!mounted) return;
      setState(() {
        if (p == null) {
          _error = 'That preset is gone.';
          return;
        }
        // keep the running timer if we only reloaded after an edit
        final changed = _preset == null || _preset!.plannedSeconds != p.plannedSeconds;
        _preset = p;
        if (changed) {
          _timer = SessionTimer(plannedSeconds: p.plannedSeconds, clock: widget.clock);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't load the preset.");
    }
  }

  // ---- timer buttons ----

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final t = _timer!;
      if (t.state == TimerState.running && t.isDone) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _start() {
    _timer!.start();
    _startTicker();
    setState(() {});
  }

  void _pause() {
    _timer!.pause();
    setState(() {});
  }

  void _resume() {
    _timer!.resume();
    setState(() {});
  }

  void _finish() {
    // finish() only works once, so tapping it a lot is fine
    if (_timer!.finish()) {
      _ticker?.cancel();
    }
    if (mounted) setState(() {});
  }

  Future<void> _reset() async {
    final ok = await _confirm('Reset the timer?', 'The time so far will be lost.', 'Reset');
    if (ok != true || !mounted) return;
    _ticker?.cancel();
    _timer!.reset();
    setState(() => _saved = false);
  }

  // ---- saving ----

  Future<bool> _saveLog(String status) async {
    if (_saving || _saved) return false; // never save the same session twice
    final p = _preset!;
    final t = _timer!;
    setState(() => _saving = true);
    try {
      await _db.insertLog(SessionLog(
        presetId: p.id!,
        startedAt: (t.startedAt ?? widget.clock.now()).toIso8601String(),
        plannedSecondsSnapshot: p.plannedSeconds,
        completedSeconds: t.completedSeconds,
        moodTagSnapshot: p.moodTag,
        status: status,
        source: 'timer',
      ));
      _saved = true;
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't save. Try again.")));
      }
      return false;
    }
  }

  Future<void> _saveToHistory() async {
    final ok = await _saveLog('finished');
    if (ok && mounted) Navigator.pop(context);
  }

  // back button: ask what to do with a session that's in progress
  Future<void> _onBack() async {
    final t = _timer;
    final unsaved = t != null &&
        !_saved &&
        (t.state == TimerState.running ||
            t.state == TimerState.paused ||
            t.state == TimerState.finished);
    if (!unsaved) {
      Navigator.pop(context);
      return;
    }
    final wasRunning = t.state == TimerState.running;
    t.stop();
    final finished = t.state == TimerState.finished;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(finished ? 'Save this session?' : 'Leave this session?'),
        content: Text(finished
            ? 'You finished it but haven\'t saved it to history.'
            : 'Save it as cancelled, or throw it away?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(finished ? 'Save' : 'Save as cancelled'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'discard') {
      Navigator.pop(context);
    } else if (choice == 'save') {
      final ok = await _saveLog(finished ? 'finished' : 'cancelled');
      if (ok && mounted) Navigator.pop(context);
    } else if (wasRunning) {
      // it was running before the dialog, so carry on
      t.resume();
    }
  }

  // ---- edit / delete preset ----

  Future<void> _edit() async {
    await Navigator.pushNamed(context, PresetEditorScreen.route, arguments: _preset);
    if (mounted) _loadPreset(_preset!.id!);
  }

  Future<void> _delete() async {
    final p = _preset!;
    try {
      final count = await _db.countLogsForPreset(p.id!);
      if (!mounted) return;
      final ok = await _confirm(
        'Delete ${p.label}?',
        count == 0
            ? 'This cannot be undone.'
            : 'Its $count session${count == 1 ? '' : 's'} will be deleted too. This cannot be undone.',
        'Delete',
      );
      if (ok != true) return;
      await _db.deletePreset(p.id!);
      if (!mounted) return;
      _ticker?.cancel();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Couldn't delete. Try again.")));
    }
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
  }

  // ---- UI ----

  String _mmss(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _stateLabel(SessionTimer t) {
    final planned = '${t.plannedSeconds ~/ 60} min planned';
    switch (t.state) {
      case TimerState.idle:
        return 'Ready · $planned';
      case TimerState.running:
        return 'Running · $planned';
      case TimerState.paused:
        return 'Paused · $planned';
      case TimerState.finished:
        return 'Finished · $planned';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preset;
    final t = _timer;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Focus Session'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        ),
        body: _error != null
            ? Center(child: Text(_error!))
            : (p == null || t == null)
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(p, t),
      ),
    );
  }

  Widget _buildBody(FocusPreset p, SessionTimer t) {
    final running = t.state == TimerState.running;
    final paused = t.state == TimerState.paused;
    final idle = t.state == TimerState.idle;
    final finished = t.state == TimerState.finished;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Text('${p.label} · ${p.moodTag}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: t.remainingSeconds / t.plannedSeconds,
                    strokeWidth: 12,
                    color: Colors.grey.shade800,
                    backgroundColor: Colors.grey.shade300,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_mmss(t.remainingSeconds),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                    Text(_stateLabel(t),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: finished ? null : (idle ? _start : (running ? _pause : _resume)),
                child: Text(idle ? 'Start' : (running ? 'Pause' : 'Resume')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: (running || paused) ? _finish : null,
                child: const Text('Finish'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: idle ? null : _reset,
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: (running || paused) ? null : _edit,
                child: const Text('Edit preset'),
              ),
            ),
          ],
        ),
        if (finished) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade700),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Planned ${t.plannedSeconds} s · Completed ${t.completedSeconds} s'),
                const Text('Status: finished · Source: timer'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_saving || _saved) ? null : _saveToHistory,
            child: const Text('Save to history'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: (running || paused) ? null : _delete,
          child: const Text('Delete preset'),
        ),
      ],
    );
  }
}
