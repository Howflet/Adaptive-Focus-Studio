import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/models/focus_preset.dart';
import 'package:adaptive_focus_studio/screens/session_screen.dart';
import 'fake_clock.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dbPath;
  late FakeClock clock;
  late int presetId;

  setUp(() {
    dbPath = '${Directory.systemTemp.path}/session_test_${DateTime.now().microsecondsSinceEpoch}.db';
    DatabaseHelper.instance = DatabaseHelper.forPath(dbPath);
    clock = FakeClock();
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    final f = File(dbPath);
    if (f.existsSync()) f.deleteSync();
  });

  // opens the session screen with a 5 minute preset, with a "Home" page under it
  Future<void> openSession(WidgetTester t) async {
    await t.runAsync(() async {
      presetId = await DatabaseHelper.instance.insertPreset(
          FocusPreset(label: 'Chem reading', moodTag: 'Calm', plannedSeconds: 300));
    });
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: RouteSettings(arguments: presetId),
                builder: (_) => SessionScreen(clock: clock),
              ),
            ),
            child: const Text('Home'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Home'));
    await settle(t);
  }

  Future<int> logCount(WidgetTester t) async {
    return (await t.runAsync(() => DatabaseHelper.instance.countLogsForPreset(presetId)))!;
  }

  testWidgets('shows the preset and a full countdown', (t) async {
    await openSession(t);
    expect(find.text('Chem reading · Calm'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('start, pause and resume change the button and the time', (t) async {
    await openSession(t);
    await t.tap(find.text('Start'));
    clock.advance(const Duration(seconds: 30));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('04:30'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);

    await t.tap(find.text('Pause'));
    await t.pump();
    clock.advance(const Duration(minutes: 1));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('04:30'), findsOneWidget); // didn't move while paused
    expect(find.text('Resume'), findsOneWidget);

    await t.tap(find.text('Resume'));
    await t.pump();
    // leave it running on purpose, the screen gets closed below
    await t.tap(find.byIcon(Icons.arrow_back));
    await t.pump();
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle(); // if the timer leaked, the test would fail here
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('finish then hammering save only creates one log', (t) async {
    await openSession(t);
    await t.tap(find.text('Start'));
    clock.advance(const Duration(seconds: 120));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Finish'));
    await t.pump();
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Planned 300 s · Completed 120 s'), findsOneWidget);

    // tap save a bunch of times without waiting
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Save to history'), warnIfMissed: false);
      await t.pump();
    }
    await settle(t);
    expect(await logCount(t), 1);
  });

  testWidgets('leaving a running session can save it as cancelled', (t) async {
    await openSession(t);
    await t.tap(find.text('Start'));
    clock.advance(const Duration(seconds: 60));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byIcon(Icons.arrow_back));
    await t.pump();
    expect(find.text('Leave this session?'), findsOneWidget);
    await t.tap(find.text('Save as cancelled'));
    await settle(t);
    expect(await logCount(t), 1);
    final db = await t.runAsync(() => DatabaseHelper.instance.database);
    final rows = await t.runAsync(() => db!.query('SessionLog'));
    expect(rows!.first['status'], 'cancelled');
    expect(rows.first['completedSeconds'], 60);
  });

  testWidgets('reset asks first and then goes back to full time', (t) async {
    await openSession(t);
    await t.tap(find.text('Start'));
    clock.advance(const Duration(seconds: 60));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Reset'));
    await t.pump();
    expect(find.text('Reset the timer?'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Reset'));
    await t.pump();
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('delete says how many sessions go too and removes everything', (t) async {
    await openSession(t);
    await t.runAsync(() async {
      final db = await DatabaseHelper.instance.database;
      for (var i = 0; i < 2; i++) {
        await db.insert('SessionLog', {
          'presetId': presetId,
          'startedAt': '2026-10-19T10:00:00',
          'plannedSecondsSnapshot': 300,
          'completedSeconds': 300,
          'moodTagSnapshot': 'Calm',
          'status': 'finished',
          'source': 'timer',
        });
      }
    });
    await t.tap(find.text('Delete preset'));
    await settle(t);
    expect(find.text('Delete Chem reading?'), findsOneWidget);
    expect(find.textContaining('Its 2 sessions will be deleted too'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await settle(t);
    expect(find.text('Home'), findsOneWidget);
    final gone = await t.runAsync(() => DatabaseHelper.instance.getPreset(presetId));
    expect(gone, isNull);
    expect(await logCount(t), 0);
  });
}
