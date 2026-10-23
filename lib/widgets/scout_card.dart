import 'package:flutter/material.dart';

import '../helpers/session_scout.dart';

// The Session Scout suggestion box on the preset editor.
class ScoutCard extends StatelessWidget {
  final ScoutResult result;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  const ScoutCard({
    super.key,
    required this.result,
    required this.onApply,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Session Scout suggestion. ${result.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade700),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session Scout (rule-based helper)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(result.message),
            if (result.hasSuggestion) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(onPressed: onApply, child: const Text('Apply')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: onDismiss, child: const Text('Dismiss')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
