import 'package:adaptive_focus_studio/helpers/clock.dart';

class FakeClock extends Clock {
  DateTime time = DateTime(2026, 10, 1, 10, 0, 0);

  @override
  DateTime now() => time;

  void advance(Duration d) => time = time.add(d);
}
