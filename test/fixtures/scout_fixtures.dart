import 'package:adaptive_focus_studio/models/session_log.dart';

// Made-up session history for the Session Scout tests. Not real data.
// Each call gets later dates so "most recent" is predictable.
int _day = 1;

SessionLog fakeLog(
  int minutes, {
  String mood = 'Calm',
  String status = 'finished',
  int? seconds,
  int presetId = 1,
}) {
  final d = _day++;
  final date = '2026-10-${d.toString().padLeft(2, '0')}T10:00:00';
  return SessionLog(
    presetId: presetId,
    startedAt: date,
    plannedSecondsSnapshot: 1500,
    completedSeconds: seconds ?? minutes * 60,
    moodTagSnapshot: mood,
    status: status,
    source: 'timer',
  );
}

List<SessionLog> calmLogs(List<int> minutes) => [for (final m in minutes) fakeLog(m)];
