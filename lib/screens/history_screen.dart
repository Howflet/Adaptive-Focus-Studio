import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../helpers/format.dart';
import '../models/session_log.dart';
import '../widgets/empty_state.dart';
import '../widgets/log_tile.dart';
import '../widgets/stat_tile.dart';
import 'log_editor_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  static const route = '/history';

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseHelper.instance;
  List<({SessionLog log, String presetLabel})> _rows = [];
  String _total = 'No sessions yet.';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // list and total both come from the database every time
  Future<void> _load() async {
    try {
      final rows = await _db.getLogs();
      final totals = await _db.getTotals();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _total = totals.count == 0
            ? 'No sessions yet.'
            : 'Total focused: ${formatTotal(totals.totalSeconds)} · n = ${totals.count}';
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load history.";
      });
    }
  }

  Future<void> _openEditor([SessionLog? log]) async {
    await Navigator.pushNamed(context, LogEditorScreen.route, arguments: log);
    _load();
  }

  Future<bool> _confirmDelete(SessionLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    try {
      await _db.deleteLog(log.id!);
      await _load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't delete. Try again.")));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatTile(title: 'Total focused time', value: _total),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
            OutlinedButton(
              onPressed: () => _openEditor(),
              child: const Text('+ Add manual entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_rows.isEmpty) {
      return const Align(
        alignment: Alignment.topCenter,
        child: EmptyState(message: 'No sessions yet.'),
      );
    }
    return ListView(
      children: [
        for (final r in _rows)
          // swipe to delete, the Delete button does the same thing
          Dismissible(
            key: ValueKey(r.log.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _confirmDelete(r.log);
              return false; // the list gets rebuilt from the db instead
            },
            background: Container(
              color: Colors.grey.shade300,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Text('Delete'),
            ),
            child: LogTile(
              log: r.log,
              presetLabel: r.presetLabel,
              onEdit: () => _openEditor(r.log),
              onDelete: () => _confirmDelete(r.log),
            ),
          ),
      ],
    );
  }
}
