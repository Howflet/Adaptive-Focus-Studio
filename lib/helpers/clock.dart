// The timer asks this for the time so tests can use a fake one
// instead of waiting real minutes.
class Clock {
  const Clock();
  DateTime now() => DateTime.now();
}
