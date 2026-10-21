import 'package:flutter_test/flutter_test.dart';

import 'package:adaptive_focus_studio/helpers/session_timer.dart';
import 'fake_clock.dart';

void main() {
  late FakeClock clock;
  late SessionTimer timer;

  setUp(() {
    clock = FakeClock();
    timer = SessionTimer(plannedSeconds: 1500, clock: clock);
  });

  test('starts idle with nothing elapsed', () {
    expect(timer.state, TimerState.idle);
    expect(timer.completedSeconds, 0);
    expect(timer.remainingSeconds, 1500);
  });

  test('counts time while running', () {
    timer.start();
    clock.advance(const Duration(seconds: 90));
    expect(timer.completedSeconds, 90);
    expect(timer.remainingSeconds, 1410);
  });

  test('no time is added while paused', () {
    timer.start();
    clock.advance(const Duration(seconds: 60));
    timer.pause();
    clock.advance(const Duration(minutes: 10));
    expect(timer.completedSeconds, 60);
  });

  test('resume carries on from where it stopped', () {
    timer.start();
    clock.advance(const Duration(seconds: 60));
    timer.pause();
    clock.advance(const Duration(minutes: 10));
    timer.resume();
    clock.advance(const Duration(seconds: 30));
    expect(timer.completedSeconds, 90);
  });

  test('finish only works once', () {
    timer.start();
    clock.advance(const Duration(seconds: 100));
    expect(timer.finish(), isTrue);
    expect(timer.finish(), isFalse);
    clock.advance(const Duration(seconds: 100));
    expect(timer.completedSeconds, 100); // clock stopped
    expect(timer.state, TimerState.finished);
  });

  test('can finish from paused', () {
    timer.start();
    clock.advance(const Duration(seconds: 45));
    timer.pause();
    expect(timer.finish(), isTrue);
    expect(timer.completedSeconds, 45);
  });

  test('cannot finish before starting', () {
    expect(timer.finish(), isFalse);
    expect(timer.state, TimerState.idle);
  });

  test('completed time is capped at planned time', () {
    timer.start();
    clock.advance(const Duration(minutes: 40)); // a very late tick
    expect(timer.completedSeconds, 1500);
    expect(timer.isDone, isTrue);
  });

  test('reset goes back to the start', () {
    timer.start();
    clock.advance(const Duration(seconds: 100));
    timer.reset();
    expect(timer.state, TimerState.idle);
    expect(timer.completedSeconds, 0);
    expect(timer.startedAt, isNull);
  });
}
