import 'package:flutter_test/flutter_test.dart';

import 'package:adaptive_focus_studio/helpers/session_scout.dart';
import 'fixtures/scout_fixtures.dart';

void main() {
  test('C1 normal: 20, 30, 25 suggests 25 and says why', () {
    final r = suggestDuration(calmLogs([20, 30, 25]), 'Calm');
    expect(r.minutes, 25);
    expect(r.clamped, false);
    expect(r.message, 'Suggests 25 min: median of your last 3 finished Calm sessions (20, 25, 30).');
    // if the next session is 22, helper and baseline are both off by 3
    expect(absoluteError(r.minutes!, 22), 3);
    expect(absoluteError(baselineSuggestion(), 22), 3);
  });

  test('C2 not enough data: only 2 finished sessions', () {
    final r = suggestDuration(calmLogs([20, 30]), 'Calm');
    expect(r.hasSuggestion, false);
    expect(r.message, 'Not enough history yet (2 of 3)');
  });

  test('C3 invalid input: 0 seconds and cancelled logs are ignored', () {
    final logs = [
      fakeLog(20),
      fakeLog(25),
      fakeLog(0, seconds: 0),
      fakeLog(30, status: 'cancelled'),
    ];
    final r = suggestDuration(logs, 'Calm');
    expect(r.hasSuggestion, false);
    expect(r.matching, 2);

    // with a third valid one the result only uses the valid ones
    final r2 = suggestDuration([...logs, fakeLog(35)], 'Calm');
    expect(r2.used, [20, 25, 35]);
    expect(r2.minutes, 25);
  });

  test('C4 boundary: clamps to 10 and to 60 and says so', () {
    final low = suggestDuration(calmLogs([5, 6, 7]), 'Calm');
    expect(low.minutes, 10);
    expect(low.clamped, true);
    expect(low.message, contains('Kept between 10 and 60'));
    expect(low.message, contains('median was 6'));

    final high = suggestDuration(calmLogs([90, 95, 100]), 'Calm');
    expect(high.minutes, 60);
    expect(high.clamped, true);
    expect(high.unclamped, 95);
  });

  test('C5 counterexample: 20, 25, 58 suggests 25, off by 30 if next is 55', () {
    final r = suggestDuration(calmLogs([20, 25, 58]), 'Calm');
    expect(r.minutes, 25);
    expect(absoluteError(r.minutes!, 55), 30);
    // the mean would have been closer here
    expect(meanOfRecent([20, 25, 58]), 34);
    expect(absoluteError(34, 55), 21);
  });

  test('C6 change of input: other mood or an edited log changes the answer', () {
    final logs = [
      ...calmLogs([20, 25, 30]),
      fakeLog(40, mood: 'Tired'),
    ];
    expect(suggestDuration(logs, 'Calm').minutes, 25);
    expect(suggestDuration(logs, 'Tired').hasSuggestion, false);

    // edit the newest calm log from 30 to 50 minutes
    final edited = [
      ...calmLogs([20, 25, 50]),
    ];
    expect(suggestDuration(edited, 'Calm').minutes, 25); // median still 25
    final edited2 = calmLogs([40, 45, 50]);
    expect(suggestDuration(edited2, 'Calm').minutes, 45);
  });

  test('only the 3 most recent matching sessions count', () {
    final r = suggestDuration(calmLogs([10, 12, 40, 45, 50]), 'Calm');
    expect(r.used, [40, 45, 50]);
    expect(r.minutes, 45);
  });

  // Small evaluation for AI_FEATURE.md: absolute error in minutes between the
  // suggestion and the next real session, helper vs the fixed 25 min baseline.
  // Fictional data, 6 cases, so this is a demonstration and not proof.
  test('evaluation: helper vs 25 min baseline on 6 made-up cases', () {
    final cases = <({List<int> last3, int next})>[
      (last3: [20, 30, 25], next: 22),
      (last3: [40, 45, 50], next: 48),
      (last3: [15, 20, 25], next: 20),
      (last3: [30, 35, 30], next: 33),
      (last3: [55, 60, 50], next: 52),
      (last3: [20, 25, 58], next: 55), // the counterexample
    ];

    var helperTotal = 0;
    var baselineTotal = 0;
    for (final c in cases) {
      final s = suggestDuration(calmLogs(c.last3), 'Calm').minutes!;
      final h = absoluteError(s, c.next);
      final b = absoluteError(baselineSuggestion(), c.next);
      helperTotal += h;
      baselineTotal += b;
      // ignore: avoid_print
      print('last3=${c.last3} next=${c.next} helper=$s (err $h) baseline=25 (err $b)');
    }
    expect(helperTotal, 42); // mean 7.0 min
    expect(baselineTotal, 96); // mean 16.0 min
  });
}
