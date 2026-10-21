import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';

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
}
