import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// db calls are real async, so wait for them outside the fake clock
// and keep pumping until the loading spinner is gone
Future<void> settle(WidgetTester t) async {
  // always give the db a little time, the spinner isn't there on a reload.
  // two rounds because a save pops the screen and then triggers a reload
  for (var i = 0; i < 2; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 50; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await t.pumpAndSettle();
}
