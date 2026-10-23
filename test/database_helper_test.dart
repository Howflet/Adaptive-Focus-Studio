import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;

  setUp(() {
    helper = DatabaseHelper.forPath(inMemoryDatabasePath);
  });

  tearDown(() async {
    await helper.close();
  });

  FocusPreset sample([String label = 'Chem reading']) =>
      FocusPreset(label: label, moodTag: 'Calm', plannedSeconds: 1500);

  test('insert then read back', () async {
    final id = await helper.insertPreset(sample());
    final p = await helper.getPreset(id);
    expect(p!.label, 'Chem reading');
    expect(p.plannedSeconds, 1500);
  });

  test('update changes the row', () async {
    final id = await helper.insertPreset(sample());
    await helper.updatePreset(FocusPreset(
        id: id, label: 'Chem lab', moodTag: 'Tired', plannedSeconds: 1800));
    final p = await helper.getPreset(id);
    expect(p!.label, 'Chem lab');
    expect(p.moodTag, 'Tired');
  });

  test('mood filter only returns that mood', () async {
    await helper.insertPreset(sample('A'));
    await helper.insertPreset(
        FocusPreset(label: 'B', moodTag: 'Stressed', plannedSeconds: 600));
    final calm = await helper.getPresets(mood: 'Calm');
    expect(calm.length, 1);
    expect(calm.first.label, 'A');
  });

  test('bad input is rejected', () async {
    expect(
        () => helper.insertPreset(
            FocusPreset(label: '', moodTag: 'Calm', plannedSeconds: 1500)),
        throwsArgumentError);
    expect(
        () => helper.insertPreset(
            FocusPreset(label: 'x', moodTag: 'Calm', plannedSeconds: 60)),
        throwsArgumentError);
  });

  test('quotes in the label do not break the query', () async {
    final id = await helper.insertPreset(sample("Bob's \"notes\"; DROP TABLE"));
    expect((await helper.getPreset(id))!.label, "Bob's \"notes\"; DROP TABLE");
    expect((await helper.getPresets()).length, 1);
  });

  test('foreign keys are on', () async {
    final db = await helper.database;
    final r = await db.rawQuery('PRAGMA foreign_keys');
    expect(r.first.values.first, 1);
    // a log for a preset that does not exist should fail
    expect(
        () => db.insert('SessionLog', {
              'presetId': 999,
              'startedAt': '2026-10-19T10:00:00',
              'plannedSecondsSnapshot': 1500,
              'completedSeconds': 0,
              'moodTagSnapshot': 'Calm',
              'status': 'finished',
              'source': 'timer',
            }),
        throwsA(isA<DatabaseException>()));
  });

  test('deleting a preset also deletes its logs', () async {
    final id = await helper.insertPreset(sample());
    final db = await helper.database;
    for (var i = 0; i < 2; i++) {
      await db.insert('SessionLog', {
        'presetId': id,
        'startedAt': '2026-10-19T10:00:00',
        'plannedSecondsSnapshot': 1500,
        'completedSeconds': 1200,
        'moodTagSnapshot': 'Calm',
        'status': 'finished',
        'source': 'timer',
      });
    }
    expect(await helper.countLogsForPreset(id), 2);
    await helper.deletePreset(id);
    expect(await helper.getPreset(id), isNull);
    expect(await helper.countLogsForPreset(id), 0);
  });

  SessionLog sampleLog(int presetId, {int seconds = 1200, String? when}) => SessionLog(
        presetId: presetId,
        startedAt: when ?? '2026-10-19T10:00:00',
        plannedSecondsSnapshot: 1500,
        completedSeconds: seconds,
        moodTagSnapshot: 'Calm',
        status: 'finished',
        source: 'manual',
      );

  test('log insert, read newest first, update and delete', () async {
    final pid = await helper.insertPreset(sample());
    final a = await helper.insertLog(sampleLog(pid, when: '2026-10-18T10:00:00'));
    await helper.insertLog(sampleLog(pid, when: '2026-10-19T10:00:00'));

    var rows = await helper.getLogs();
    expect(rows.length, 2);
    expect(rows.first.log.startedAt, '2026-10-19T10:00:00'); // newest first
    expect(rows.first.presetLabel, 'Chem reading');

    final old = rows.firstWhere((r) => r.log.id == a).log;
    await helper.updateLog(SessionLog(
      id: old.id,
      presetId: old.presetId,
      startedAt: old.startedAt,
      plannedSecondsSnapshot: old.plannedSecondsSnapshot,
      completedSeconds: 600,
      moodTagSnapshot: old.moodTagSnapshot,
      status: old.status,
      source: old.source,
      note: 'fixed',
    ));
    rows = await helper.getLogs();
    expect(rows.firstWhere((r) => r.log.id == a).log.completedSeconds, 600);
    expect(rows.firstWhere((r) => r.log.id == a).log.note, 'fixed');

    await helper.deleteLog(a);
    expect((await helper.getLogs()).length, 1);
  });

  test('totals add up and refresh after changes', () async {
    final pid = await helper.insertPreset(sample());
    expect((await helper.getTotals()).count, 0);
    final id = await helper.insertLog(sampleLog(pid, seconds: 600));
    await helper.insertLog(sampleLog(pid, seconds: 1200));
    var t = await helper.getTotals();
    expect(t.totalSeconds, 1800);
    expect(t.count, 2);
    await helper.deleteLog(id);
    t = await helper.getTotals();
    expect(t.totalSeconds, 1200);
    expect(t.count, 1);
  });

  test('bad logs are rejected', () async {
    final pid = await helper.insertPreset(sample());
    expect(() => helper.insertLog(sampleLog(pid, seconds: -5)), throwsArgumentError);
    final future = DateTime.now().add(const Duration(days: 3)).toIso8601String();
    expect(() => helper.insertLog(sampleLog(pid, when: future)), throwsArgumentError);
    expect(
        () => helper.insertLog(SessionLog(
            presetId: pid,
            startedAt: '2026-10-19T10:00:00',
            plannedSecondsSnapshot: 1500,
            completedSeconds: 10,
            moodTagSnapshot: 'Calm',
            status: 'finished',
            source: 'manual',
            note: 'x' * 201)),
        throwsArgumentError);
  });
}
