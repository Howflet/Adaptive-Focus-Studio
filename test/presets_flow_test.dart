import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/main.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dbPath;

  setUp(() {
    dbPath = '${Directory.systemTemp.path}/focus_test_${DateTime.now().microsecondsSinceEpoch}.db';
    DatabaseHelper.instance = DatabaseHelper.forPath(dbPath);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    final f = File(dbPath);
    if (f.existsSync()) f.deleteSync();
  });

  testWidgets('empty state shows when there are no presets', (t) async {
    await t.pumpWidget(const FocusApp());
    await settle(t);
    expect(find.text('No presets yet. Tap + to create one.'), findsOneWidget);
    expect(find.text('No sessions yet.'), findsOneWidget);
  });

  testWidgets('empty label shows an inline error and does not save', (t) async {
    await t.pumpWidget(const FocusApp());
    await settle(t);
    await t.tap(find.byIcon(Icons.add));
    await settle(t);
    await t.tap(find.text('Save'));
    await t.pump();
    expect(find.text('Label is required'), findsOneWidget);
    expect(find.text('New Preset'), findsOneWidget); // still on the editor
  });

  testWidgets('saved preset shows up and is still there after a restart', (t) async {
    await t.pumpWidget(const FocusApp());
    await settle(t);
    await t.tap(find.byIcon(Icons.add));
    await settle(t);
    await t.enterText(find.byType(TextField), 'Essay draft');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(find.text('Essay draft'), findsOneWidget);
    expect(find.text('Calm · 25 min'), findsOneWidget);

    // "restart": throw away the app and the open connection, same db file
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() => DatabaseHelper.instance.close());
    await t.pumpWidget(const FocusApp());
    await settle(t);
    expect(find.text('Essay draft'), findsOneWidget);
  });
}
