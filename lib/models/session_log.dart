// One finished or cancelled session. It copies the preset's mood and planned
// time so editing the preset later doesn't change old history.
class SessionLog {
  final int? id;
  final int presetId;
  final String startedAt; // ISO-8601
  final int plannedSecondsSnapshot;
  final int completedSeconds;
  final String moodTagSnapshot;
  final String status; // finished or cancelled
  final String source; // timer or manual
  final String? note;

  SessionLog({
    this.id,
    required this.presetId,
    required this.startedAt,
    required this.plannedSecondsSnapshot,
    required this.completedSeconds,
    required this.moodTagSnapshot,
    required this.status,
    required this.source,
    this.note,
  });

  String? validate() {
    if (completedSeconds < 0) return 'Completed time can\'t be negative';
    if (status != 'finished' && status != 'cancelled') return 'Bad status';
    if (source != 'timer' && source != 'manual') return 'Bad source';
    if (note != null && note!.length > 200) return 'Note can be 200 characters max';
    final started = DateTime.tryParse(startedAt);
    if (started == null) return 'Bad date';
    // a minute of slack so "now" doesn't count as the future
    if (started.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return 'Date can\'t be in the future';
    }
    return null;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'presetId': presetId,
        'startedAt': startedAt,
        'plannedSecondsSnapshot': plannedSecondsSnapshot,
        'completedSeconds': completedSeconds,
        'moodTagSnapshot': moodTagSnapshot,
        'status': status,
        'source': source,
        'note': note,
      };

  factory SessionLog.fromMap(Map<String, Object?> m) => SessionLog(
        id: m['id'] as int,
        presetId: m['presetId'] as int,
        startedAt: m['startedAt'] as String,
        plannedSecondsSnapshot: m['plannedSecondsSnapshot'] as int,
        completedSeconds: m['completedSeconds'] as int,
        moodTagSnapshot: m['moodTagSnapshot'] as String,
        status: m['status'] as String,
        source: m['source'] as String,
        note: m['note'] as String?,
      );
}
