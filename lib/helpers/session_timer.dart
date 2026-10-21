import 'clock.dart';

enum TimerState { idle, running, paused, finished }

// The timer rules, kept out of the widget so they can be tested.
// Time is worked out from timestamps, not by counting ticks, so a late
// tick can't change the answer and time never goes up while paused.
class SessionTimer {
  final Clock clock;
  final int plannedSeconds;

  SessionTimer({required this.plannedSeconds, this.clock = const Clock()});

  TimerState state = TimerState.idle;
  DateTime? startedAt; // first time Start was pressed
  DateTime? _segmentStart; // when the current running stretch began
  Duration _banked = Duration.zero; // time from earlier running stretches

  Duration get elapsed {
    var total = _banked;
    if (state == TimerState.running) {
      total += clock.now().difference(_segmentStart!);
    }
    return total;
  }

  // never more than the planned time
  int get completedSeconds {
    final s = elapsed.inSeconds;
    return s > plannedSeconds ? plannedSeconds : s;
  }

  int get remainingSeconds => plannedSeconds - completedSeconds;

  bool get isDone => remainingSeconds <= 0;

  void start() {
    if (state != TimerState.idle) return;
    startedAt = clock.now();
    _segmentStart = startedAt;
    state = TimerState.running;
  }

  void pause() {
    if (state != TimerState.running) return;
    _banked = elapsed;
    state = TimerState.paused;
  }

  void resume() {
    if (state != TimerState.paused) return;
    _segmentStart = clock.now();
    state = TimerState.running;
  }

  // true only the first time, so a double tap can't finish twice
  bool finish() {
    if (state != TimerState.running && state != TimerState.paused) return false;
    _banked = elapsed;
    state = TimerState.finished;
    return true;
  }

  // used for the "save as cancelled" case, stops the clock without finishing
  void stop() {
    if (state == TimerState.running) {
      _banked = elapsed;
      state = TimerState.paused;
    }
  }

  void reset() {
    state = TimerState.idle;
    startedAt = null;
    _segmentStart = null;
    _banked = Duration.zero;
  }
}
