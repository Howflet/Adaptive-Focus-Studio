import '../models/session_log.dart';

// Session Scout: a rule-based helper (not a trained model).
// It suggests a starting duration from the user's own finished sessions
// in the same mood: the median of the last 3, rounded, kept between 10 and 60.
// It never saves anything, the editor only uses it to fill the slider.

const scoutWindow = 3;
const scoutMin = 10;
const scoutMax = 60;
const baselineMinutes = 25;

class ScoutResult {
  final int? minutes; // null when there isn't enough history
  final int matching; // how many usable sessions were found
  final List<int> used; // the minutes that were used, sorted
  final bool clamped;
  final int? unclamped;
  final String mood;

  const ScoutResult({
    required this.minutes,
    required this.matching,
    required this.used,
    required this.clamped,
    required this.unclamped,
    required this.mood,
  });

  bool get hasSuggestion => minutes != null;

  String get message {
    if (minutes == null) {
      return 'Not enough history yet ($matching of $scoutWindow)';
    }
    final base = 'Suggests $minutes min: median of your last $scoutWindow '
        'finished $mood sessions (${used.join(', ')}).';
    if (!clamped) return base;
    return '$base Kept between $scoutMin and $scoutMax min (median was $unclamped).';
  }
}

ScoutResult suggestDuration(List<SessionLog> logs, String mood) {
  // finished, same mood, and actual time above 0. Cancelled/invalid ones are skipped.
  final usable = logs
      .where((l) =>
          l.moodTagSnapshot == mood && l.status == 'finished' && l.completedSeconds > 0)
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt)); // newest first

  final recent = usable.take(scoutWindow).toList();
  if (recent.length < scoutWindow) {
    return ScoutResult(
      minutes: null,
      matching: recent.length,
      used: const [],
      clamped: false,
      unclamped: null,
      mood: mood,
    );
  }

  final mins = recent.map((l) => (l.completedSeconds / 60).round()).toList()..sort();
  final median = mins[mins.length ~/ 2]; // odd count so this is the middle one
  final clamped = median < scoutMin || median > scoutMax;
  return ScoutResult(
    minutes: median.clamp(scoutMin, scoutMax),
    matching: recent.length,
    used: mins,
    clamped: clamped,
    unclamped: median,
    mood: mood,
  );
}

// The comparison methods used for the write-up, not used by the app itself.
int baselineSuggestion() => baselineMinutes;

int meanOfRecent(List<int> recentMinutes) =>
    (recentMinutes.reduce((a, b) => a + b) / recentMinutes.length).round();

int absoluteError(int suggested, int actual) => (suggested - actual).abs();
