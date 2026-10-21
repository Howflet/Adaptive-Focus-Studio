import 'package:flutter/material.dart';

import '../helpers/format.dart';
import '../models/session_log.dart';

class LogTile extends StatelessWidget {
  final SessionLog log;
  final String presetLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LogTile({
    super.key,
    required this.log,
    required this.presetLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = shortDate(DateTime.parse(log.startedAt));
    final done = log.completedSeconds ~/ 60;
    final planned = log.plannedSecondsSnapshot ~/ 60;
    final manual = log.source == 'manual';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade700),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$date · $presetLabel',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$done / $planned min · ${log.status} · ${manual ? 'MANUAL' : 'timer'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (log.note != null && log.note!.isNotEmpty)
                  Text(log.note!, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit')),
          TextButton(onPressed: onDelete, child: const Text('Delete')),
        ],
      ),
    );
  }
}
