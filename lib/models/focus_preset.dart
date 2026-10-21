// A saved thing to study, like "Chem reading", with a mood and planned time.
const moodTags = ['Calm', 'Energized', 'Tired', 'Stressed'];

class FocusPreset {
  final int? id;
  final String label;
  final String moodTag;
  final int plannedSeconds;

  FocusPreset({
    this.id,
    required this.label,
    required this.moodTag,
    required this.plannedSeconds,
  });

  // returns an error message or null if everything is fine
  String? validate() {
    final name = label.trim();
    if (name.isEmpty) return 'Label is required';
    if (name.length > 40) return 'Label can be 40 characters max';
    if (!moodTags.contains(moodTag)) return 'Pick a mood';
    if (plannedSeconds < 300 || plannedSeconds > 7200) {
      return 'Duration must be 5 to 120 minutes';
    }
    return null;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'label': label.trim(),
        'moodTag': moodTag,
        'plannedSeconds': plannedSeconds,
      };

  factory FocusPreset.fromMap(Map<String, Object?> m) => FocusPreset(
        id: m['id'] as int,
        label: m['label'] as String,
        moodTag: m['moodTag'] as String,
        plannedSeconds: m['plannedSeconds'] as int,
      );
}
