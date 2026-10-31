# Adaptive Focus Studio

Offline study timer app for my Mobile App Dev project 1 (GSU, Fall 2026).

You save presets for the stuff you study (a label, a mood and a planned length),
run a timer you can pause, and get a receipt showing planned vs completed time.
After a few sessions a small helper called Session Scout suggests a starting
length based on your own history. Everything stays on the phone. No accounts,
no cloud, no network calls.

Made by Howard Fletcher (sole developer, undergraduate pathway).

- GitHub: https://github.com/Howflet/Adaptive-Focus-Studio
- ClickUp board: https://app.clickup.com/90141788557/v/b/li/901422483479
- Board snapshots: `docs/snapshots/` (Oct 20, Oct 23 and Oct 31)
- Kanban evidence PDF: `docs/Kanban_Contribution_Evidence.pdf`
- Demo video: TODO (link goes here)
- Slides: `docs/Adaptive_Focus_Studio_Slides.pptx`

## What's in it

| Screen | What it does |
|---|---|
| 1. Presets | list of presets, mood filter chips, average completed session tile, + button, History and Settings links |
| 2. Preset editor | label, mood, duration slider (5 to 120 min), Session Scout card, inline errors |
| 3. Focus session | countdown ring, start / pause / resume / finish / reset, receipt, save to history, edit or delete the preset |
| 4. History | list of sessions, total focused time, edit, delete (confirms first), add manual entry |
| 5. Settings | default duration, reduce motion, sound effects, confirm before reset |

## Setup

You need Flutter (I used 3.47.2 stable, Dart 3.13) and an Android emulator or phone.

```bash
git clone https://github.com/Howflet/Adaptive-Focus-Studio.git
cd Adaptive-Focus-Studio
flutter pub get
flutter run
```

Run the tests:

```bash
flutter test
```

Build an APK:

```bash
flutter build apk --release
```

The APK ends up in `build/app/outputs/flutter-apk/`.

### Packages

| Package | Why |
|---|---|
| sqflite | the two SQLite tables |
| path | building the database file path |
| shared_preferences | the 4 settings |
| sqflite_common_ffi (dev only) | lets the tests run SQLite on the computer |

## How to use it

1. Open the app. If there are no presets, tap **+**.
2. Type a label, pick a mood, set the slider, press **Save**. The label can be 1 to 40 characters and the length 5 to 120 minutes, otherwise you get an error under the field.
3. Once you have at least 3 finished sessions in a mood, the editor shows a **Session Scout** suggestion for that mood. **Apply** moves the slider to the suggestion (nothing is saved until you press Save). **Dismiss** hides it.
4. Tap a preset to open the timer. **Start**, then **Pause** or **Finish** whenever. Finish shows a receipt; **Save to history** keeps it. **Reset** throws the time away (it asks first unless you turned that off in Settings).
5. If you press back during a session it asks whether to save it as cancelled, throw it away, or keep going.
6. **History** shows every saved session. Use **Edit** to fix the minutes, **Delete** (or swipe left) to remove one, or **+ Add manual entry** for a session you did without the timer. Manual ones are marked MANUAL.
7. **Settings** save as soon as you change them.

To delete a preset, open it (tap the card) and press **Delete preset**. It tells you how many sessions will be deleted along with it.

## Data

Two SQLite tables, one parent and one child.

**FocusPreset**

| Field | Type | Notes |
|---|---|---|
| id | integer | primary key |
| label | text | required, 1 to 40 characters |
| moodTag | text | Calm, Energized, Tired or Stressed |
| plannedSeconds | integer | 300 to 7200 |

**SessionLog**

| Field | Type | Notes |
|---|---|---|
| id | integer | primary key |
| presetId | integer | foreign key to FocusPreset |
| startedAt | text | ISO-8601, not in the future |
| plannedSecondsSnapshot | integer | copied from the preset when the log is made |
| completedSeconds | integer | 0 or more |
| moodTagSnapshot | text | copied from the preset |
| status | text | finished or cancelled |
| source | text | timer or manual |
| note | text | optional, up to 200 characters |

Deleting a preset deletes its logs too, in one transaction, with foreign keys
turned on. The app tells you how many logs will go before it does it. All
queries use `?` placeholders.

Settings are in SharedPreferences: `defaultDurationMinutes` (25),
`reduceMotion` (false), `soundEnabled` (false), `confirmBeforeReset` (true).

## Folders

- `lib/screens` the 5 screens
- `lib/widgets` small reusable widgets (PresetCard, MoodChip, StatTile, EmptyState, LogTile, ScoutCard)
- `lib/data` database helper and settings store
- `lib/models` FocusPreset and SessionLog
- `lib/helpers` timer rules, Clock, Session Scout, formatting
- `test` automated tests (56 of them)
- `docs` board snapshots and more

## Other docs

- [ARCHITECTURE.md](ARCHITECTURE.md) how it's put together and why
- [AI_FEATURE.md](AI_FEATURE.md) Session Scout write-up, cases and results
- [REPORT.md](REPORT.md) project report

## Known issues

- Session Scout looks at the last 3 sessions only, so it can't see a trend (see the counterexample in AI_FEATURE.md).
- A running timer is not restored if the app gets killed. Saved sessions and settings always come back.
- The mood chips scroll sideways instead of fitting on one line on narrow screens.
- "Sound effects" only plays the phone's built-in click sound when you finish. There are no custom sounds.
- The tests run SQLite on the computer (sqflite_common_ffi), not on a phone, so they don't replace trying it on a device.
- Landscape and big text sizes haven't been properly checked yet.
- Tested on a Galaxy S22 and on an Android 15 emulator, not on a second physical phone. No peer observation, see REPORT.md.
