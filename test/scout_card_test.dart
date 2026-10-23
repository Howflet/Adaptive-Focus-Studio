import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/main.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'test_helpers.dart';
import 'fixtures/scout_fixtures.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dbPath;

  setUp(() {
    dbPath = '${Directory.systemTemp.path}/scout_test_${DateTime.now().microsecondsSinceEpoch}.db';
    DatabaseHelper.instance = DatabaseHelper.forPath(dbPath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    final f = File(dbPath);
    if (f.existsSync()) f.deleteSync();
  });

  // one preset and three finished Calm sessions: 20, 30, 25 minutes
  Future<void> seedCalmHistory(WidgetTester t,
      [List<int> minutes = const [20, 30, 25]]) async {
    await t.runAsync(() async {
      final db = DatabaseHelper.instance;
      final id = await db.insertPreset(
          FocusPreset(label: 'Old one', moodTag: 'Calm', plannedSeconds: 1500));
      for (final m in minutes) {
        await db.insertLog(fakeLog(m, presetId: id));
      }
    });
  }

  Future<void> openEditor(WidgetTester t) async {
    await t.pumpWidget(const FocusApp());
    await settle(t);
    await t.tap(find.byIcon(Icons.add));
    await settle(t);
  }

  testWidgets('card explains the suggestion', (t) async {
    await seedCalmHistory(t);
    await openEditor(t);
    expect(find.textContaining('Suggests 25 min: median of your last 3 finished Calm'),
        findsOneWidget);
  });

  testWidgets('Apply moves the slider to the suggestion but does not save', (t) async {
    await seedCalmHistory(t, [40, 50, 45]);
    await openEditor(t);
    expect(find.text('25 min'), findsOneWidget); // default from settings
    await t.tap(find.text('Apply'));
    await t.pump();
    expect(find.text('45 min'), findsOneWidget);
    final presets = (await t.runAsync(() => DatabaseHelper.instance.getPresets()))!;
    expect(presets.length, 1); // still only the seeded one
  });

  testWidgets('not enough history shows the message and no Apply button', (t) async {
    await t.runAsync(() async {
      final db = DatabaseHelper.instance;
      final id = await db.insertPreset(
          FocusPreset(label: 'Old one', moodTag: 'Calm', plannedSeconds: 1500));
      await db.insertLog(fakeLog(20, presetId: id));
      await db.insertLog(fakeLog(30, presetId: id));
    });
    await openEditor(t);
    expect(find.text('Not enough history yet (2 of 3)'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);
  });

  testWidgets('Dismiss hides the card', (t) async {
    await seedCalmHistory(t);
    await openEditor(t);
    await t.tap(find.text('Dismiss'));
    await t.pump();
    expect(find.textContaining('Session Scout'), findsNothing);
  });

  testWidgets('C6: changing the mood updates the card right away', (t) async {
    await seedCalmHistory(t);
    await openEditor(t);
    expect(find.textContaining('Suggests 25 min'), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Tired').last);
    await t.pumpAndSettle();
    expect(find.text('Not enough history yet (0 of 3)'), findsOneWidget);
  });

  testWidgets('C7: tapping Apply five times then Save once saves exactly one preset', (t) async {
    await seedCalmHistory(t);
    await openEditor(t);
    await t.enterText(find.byType(TextField), 'New preset');
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Apply'));
      await t.pump();
    }
    // nothing has been saved yet, only the old preset exists
    var presets = (await t.runAsync(() => DatabaseHelper.instance.getPresets()))!;
    expect(presets.length, 1);

    await t.tap(find.text('Save'));
    await settle(t);
    presets = (await t.runAsync(() => DatabaseHelper.instance.getPresets()))!;
    expect(presets.length, 2);
    final saved = presets.firstWhere((p) => p.label == 'New preset');
    expect(saved.plannedSeconds, 25 * 60);
    // no new log got created either
    final logs = (await t.runAsync(() => DatabaseHelper.instance.getLogs()))!;
    expect(logs.length, 3);
  });
}
