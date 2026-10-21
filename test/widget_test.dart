import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:adaptive_focus_studio/data/database_helper.dart';
import 'package:adaptive_focus_studio/main.dart';
import 'test_helpers.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('app starts on the presets screen', (tester) async {
    DatabaseHelper.instance = DatabaseHelper.forPath(inMemoryDatabasePath);
    await tester.pumpWidget(const FocusApp());
    await settle(tester);
    expect(find.text('Focus Presets'), findsOneWidget);
    await tester.runAsync(() => DatabaseHelper.instance.close());
  });
}
