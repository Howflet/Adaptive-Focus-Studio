# Architecture

Short version: Flutter UI on top, plain Dart logic in the middle, SQLite and
SharedPreferences at the bottom. I kept it simple on purpose, no state
management package.

## Layers

```
screens / widgets          what you see (lib/screens, lib/widgets)
      |
helpers (pure Dart)        timer rules, Session Scout, formatting (lib/helpers)
      |
data                       DatabaseHelper (sqlite), SettingsStore (prefs) (lib/data)
      |
models                     FocusPreset, SessionLog (lib/models)
```

Screens call the data layer and the helpers. The helpers don't import any
widgets and don't touch the database, so they can be tested with plain Dart
objects.

## State: who owns what

I used StatefulWidget + setState. There are only 5 screens and none of them
share live state, so a state management package would have been more setup than
help.

- **Database is the source of truth.** The presets screen and history screen
  don't keep their own copy of the data in sync. After any insert, update or
  delete they reload the list, the average and the total from SQLite. That way
  the numbers can't drift from what's actually saved.
- **Screens reload when you come back.** Navigation goes through a `_go()` helper on
  the presets screen that awaits the pushed route and then reloads.
- **Timer state lives in memory on screen 3 only.** It is not saved unless the
  user saves the session.
- **Settings** are held in `SettingsStore.instance.current`, a ValueNotifier.
  `FocusApp` listens to it (for reduce motion) and the screens read from it when
  they need a value. It's loaded once in `main()`.

## Data layer

`DatabaseHelper` owns the database connection. Widgets never open the database
themselves. It creates both tables, turns on foreign keys in `onConfigure`, and
exposes the create / read / update / delete methods for both tables plus
`getTotals()` and `getAverageCompleted()` for the numbers on screens 1 and 4.

- Every query uses `?` placeholders. There's a test with quotes in the label to
  check that.
- Models validate themselves (`validate()`), and the helper refuses to write
  invalid data. The forms also show the same errors inline.
- Deleting a preset runs in a transaction that deletes its logs first and then
  the preset, so it's both or neither.
- `DatabaseHelper.instance` isn't final so tests can swap in a temporary
  database file. This is a lighter version of injecting a repository. It works
  for this size of app, but a proper injected repository would be cleaner (see
  trade-offs below).

**Why two storage types:** presets and sessions are structured records with a
parent and child, so SQLite. Settings are four simple key/value pairs, so
SharedPreferences is enough. Nothing leaves the device.

## The timer (screen 3)

The rules live in `SessionTimer` (lib/helpers/session_timer.dart), not in the
widget.

- Time is worked out from timestamps (`clock.now()` minus when the current
  running stretch began, plus time banked from earlier stretches). It does not
  count ticks, so a late tick can't throw it off and nothing is added while
  paused.
- Completed time is capped at the planned time.
- `finish()` returns true only the first time, so tapping it a lot can't finish
  twice. The save button is also guarded by `_saving` and `_saved` flags so
  five taps make one log.
- `Clock` is a tiny class the timer reads the time from. Tests replace it with
  `FakeClock` so they don't wait real minutes.
- Lifecycle: `dispose()` cancels the periodic timer, every async callback checks
  `mounted` before calling `setState`, and the back button asks what to do with
  a running session. After the app comes back from the background the time is
  right because it's recalculated from timestamps.

## Session Scout

`suggestDuration(logs, mood)` in lib/helpers/session_scout.dart is a pure
function: list of logs in, a result object out. The editor screen only asks it
for a result and shows a `ScoutCard`. It never saves anything itself. Details
are in [AI_FEATURE.md](AI_FEATURE.md).

## Error handling

- Forms show inline errors for bad input (label, duration, minutes).
- Database failures show a SnackBar ("Couldn't save. Try again.") and keep what
  was typed.
- Lists show a spinner while loading, a message if loading fails, and an empty
  state if there's nothing yet.
- If SharedPreferences can't be read, settings fall back to the defaults.

## Testing

56 tests, run with `flutter test`:

- database helper and models (CRUD, validation, foreign keys, delete policy, totals)
- timer rules with a fake clock
- Session Scout cases and a small evaluation
- widget tests for the presets, session, history, editor and settings flows,
  including "save, restart, still there" and "tap save five times, one log"

Widget tests that touch the database wait for real async work with
`tester.runAsync` (see `test/test_helpers.dart`), since sqflite doesn't run on
the fake test clock.

## Trade-offs

- No Provider/Riverpod/BLoC. Fine for 5 screens, but it means each screen
  reloads from the database itself instead of reacting to shared state.
- `DatabaseHelper` is a swappable singleton and not an injected repository, so
  screens can't be given a fake repository, only a different database file.
- Only the timer rules and Session Scout are fully separated from the UI. The
  screens still call the database helper directly.
- The timer isn't restored after the app is killed. I left that out on purpose
  (it's out of scope in the proposal).
