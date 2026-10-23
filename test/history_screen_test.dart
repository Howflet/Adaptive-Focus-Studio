import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/main.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/models/session_log.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dbPath;
  late int presetId;

  setUp(() {
    dbPath = '${Directory.systemTemp.path}/history_test_${DateTime.now().microsecondsSinceEpoch}.db';
    DatabaseHelper.instance = DatabaseHelper.forPath(dbPath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    final f = File(dbPath);
    if (f.existsSync()) f.deleteSync();
  });

  Future<void> seed(WidgetTester t, {int logs = 0}) async {
    await t.runAsync(() async {
      presetId = await DatabaseHelper.instance.insertPreset(
          FocusPreset(label: 'Chem reading', moodTag: 'Calm', plannedSeconds: 1500));
      for (var i = 0; i < logs; i++) {
        await DatabaseHelper.instance.insertLog(SessionLog(
          presetId: presetId,
          startedAt: '2026-10-1${i + 1}T10:00:00',
          plannedSecondsSnapshot: 1500,
          completedSeconds: 1200,
          moodTagSnapshot: 'Calm',
          status: 'finished',
          source: i == 0 ? 'manual' : 'timer',
        ));
      }
    });
  }

  Future<void> openHistory(WidgetTester t) async {
    await t.pumpWidget(const FocusApp());
    await settle(t);
    await t.tap(find.text('History'));
    await settle(t);
  }

  testWidgets('empty history says no sessions yet', (t) async {
    await openHistory(t);
    expect(find.text('No sessions yet.'), findsNWidgets(2)); // tile + empty box
  });

  testWidgets('lists logs with total and marks manual ones', (t) async {
    await seed(t, logs: 2);
    await openHistory(t);
    expect(find.text('Total focused: 40 min · n = 2'), findsOneWidget);
    expect(find.textContaining('MANUAL'), findsOneWidget);
    expect(find.textContaining('20 / 25 min · finished · timer'), findsOneWidget);
  });

  testWidgets('editing minutes updates the row and the total', (t) async {
    await seed(t, logs: 1);
    await openHistory(t);
    await t.tap(find.text('Edit'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, '20'), '45');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(find.textContaining('45 / 25 min'), findsOneWidget);
    expect(find.text('Total focused: 45 min · n = 1'), findsOneWidget);
  });

  testWidgets('delete asks first, cancel keeps it, confirm removes it', (t) async {
    await seed(t, logs: 2);
    await openHistory(t);
    await t.tap(find.text('Delete').first);
    await t.pumpAndSettle();
    expect(find.text('Delete this session?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Total focused: 40 min · n = 2'), findsOneWidget);

    await t.tap(find.text('Delete').first);
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await settle(t);
    expect(find.text('Total focused: 20 min · n = 1'), findsOneWidget);
  });

  testWidgets('manual entry saves and shows up marked MANUAL', (t) async {
    await seed(t);
    await openHistory(t);
    await t.tap(find.text('+ Add manual entry'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, 'Completed minutes *'), '30');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(find.textContaining('30 / 25 min · finished · MANUAL'), findsOneWidget);
    expect(find.text('Total focused: 30 min · n = 1'), findsOneWidget);
  });

  testWidgets('manual entry with no minutes shows an inline error', (t) async {
    await seed(t);
    await openHistory(t);
    await t.tap(find.text('+ Add manual entry'));
    await settle(t);
    await t.tap(find.text('Save'));
    await t.pump();
    expect(find.text('Enter minutes, 0 or more'), findsOneWidget);
  });
}
