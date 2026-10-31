# Project report: Adaptive Focus Studio

Howard Fletcher, Mobile App Development, Project 1, Fall 2026
(sole developer, undergraduate pathway)

Repo: https://github.com/Howflet/Adaptive-Focus-Studio
Board: https://app.clickup.com/90141788557/v/b/li/901422483479

The task to code to test trace for the video is still a TODO, since I'll pick the
card when I record it.

## 1. What I built

An offline Flutter app for planning and timing study sessions. It has five
screens (presets, preset editor, focus session, history, settings), two related
SQLite tables (FocusPreset and SessionLog), settings in SharedPreferences, and
a small rule-based helper called Session Scout.

It matches the proposal. What changed from the plan:

- The mood filter, average and settings landed a few days after their due date,
  since I did the screens in a different order than the board (see section 4).
- Sound effects is a toggle that plays the built-in click on finish. I didn't add
  custom sounds.
- The editor's Session Scout card, Apply and Dismiss are all in as planned.

## 2. Requirements checklist

| Requirement | Where |
|---|---|
| 5 distinct screens with navigation | `lib/screens`, named routes in `lib/main.dart` |
| Two related SQLite tables with full CRUD | FocusPreset (parent), SessionLog (child), `lib/data/database_helper.dart` |
| Validation | models' `validate()`, inline form errors |
| Delete policy | deleting a preset deletes its logs in a transaction after a dialog with the count |
| SharedPreferences settings | `lib/data/settings_store.dart` |
| Filter and aggregate | mood filter and average on screen 1, total focused time on screen 4 |
| Activity workflow | timer: start, pause, resume, finish, reset |
| Dialogs and gestures | delete and reset confirmations, swipe to delete a history row |
| Numeric control | duration slider, 5 to 120 min in steps of 5 |
| StatelessWidget composition | PresetCard, MoodChip, StatTile, EmptyState, LogTile, ScoutCard |
| StatefulWidget classes | the screens and the editor forms |
| Lifecycle cleanup | timer cancelled in `dispose()`, `mounted` checks |
| Smart helper | Session Scout, see AI_FEATURE.md |
| No cloud | no network code, GitHub and ClickUp only for planning |

## 3. Testing

**Automated:** 56 tests, all passing at the time of writing (`flutter test`),
and `flutter analyze` is clean. They cover the database, the timer rules with a
fake clock, Session Scout cases C1 to C7, and widget flows for every screen,
including "save, restart, still there" and "tap save five times, one log".
Details in ARCHITECTURE.md.

**Manual test log (Galaxy S22, SM-S901U1, Android 16, release APK, Oct 31):**

I ran these on the S22, and again on an Android emulator (Pixel 6 profile,
Android 15 / API 35, arm64). On both I installed the release APK and tapped
through it over adb. The emulator was in airplane mode the whole time. I didn't
turn airplane mode on for the S22, so on the phone the offline part is untested.
The app has no network code either way.

| # | What I did | Device / emulator | Expected | Actual | Pass? |
|---|---|---|---|---|---|
| 1 | Create a preset ("Read chapter 4", Calm, 25 min), force stop the app, reopen | S22 | preset still there | still listed, Calm, 25 min | pass (airplane mode off) |
| 1b | Same, with airplane mode on | emulator | preset still there | still listed, Calm, 25 min | pass |
| 2 | Run a 65 second session, finish, save, force stop, reopen | S22 | session in history, average updated | History shows "1 / 25 min, finished, timer", total 1 min, home tile "1 min (from 1 sessions)" | pass |
| 3 | Same session test on a second device | emulator, airplane mode on | same | same: receipt 65 s, History "1 / 25 min", home tile "1 min (from 1 sessions)" | pass |
| 4 | Turn on Sound effects, force stop, reopen Settings | S22 | setting kept | first try: "Couldn't save settings." and it reset to off. After the fix below: stayed on | fail, then pass |
| 4b | Same setting test after the fix | emulator, airplane mode on | setting kept | stayed on, no error | pass |

The emulator is a second environment, not a second physical phone.

Test 4 found a real bug that the 56 automated tests couldn't see. In the release
build the settings never saved. The log showed a `NoSuchMethodError` from the
shared_preferences plugin, which points to R8 shrinking removing a method the
plugin needs. Turning off minify and shrinkResources for the release build in
`android/app/build.gradle.kts` fixed it (branch `fix/release-settings-save`).
The debug build and the tests never hit this because they don't use R8.

**Peer observation and revision:** not done. This is a solo project and I
chose to skip it, so there is no peer feedback or before/after change to show.

## 4. Workflow (ClickUp and GitHub)

- Board columns: To Do, In Progress, In Review, Complete, with a limit of 2 cards
  in progress and 2 in review. A card moved to Complete only after its pull
  request was merged.
- Every feature went through a branch and a pull request (PRs 1 to 8 so far).
- Board snapshots so far: Oct 20 and Oct 23 in `docs/snapshots/`. The Kanban
  evidence PDF is `docs/Kanban_Contribution_Evidence.pdf`. I missed the Oct 24 and Oct 27
  snapshots.

Honest notes on the schedule:

| Card | Due | Done |
|---|---|---|
| Create the repository and Flutter project | Oct 18 | Oct 20 |
| Database helper and FocusPreset CRUD | Oct 19 | Oct 20 |
| Screens 1 and 2 | Oct 20 | Oct 20 |
| Screen 3 timer | Oct 21 | Oct 20 |
| SessionLog CRUD and screen 4 | Oct 22 | Oct 23 |
| Mood filter, average and settings | Oct 22 | Oct 23 |
| Session Scout | Oct 23 | Oct 23 |

The first two cards were late, and the early commits are bunched up. The
git history has 52 commits on main and 43 of them are on two days (Oct 20 and
Oct 23), then docs after that.
Task to code to test trace for the video: TODO (pick one card, for example
Session Scout: card, PR 7, `test/session_scout_test.dart`).

## 5. Problems I ran into

- **Widget tests and sqflite:** database calls don't run on the fake test clock,
  so tests hung or saw empty screens. Fixed with `tester.runAsync` and a shared
  `settle()` helper in `test/test_helpers.dart`.
- **A test clock in the future:** after adding "date can't be in the future"
  validation, my timer tests stopped saving logs because the fake clock was set
  to a future date. Moved it to a past date.
- **Merge conflict:** settings and Session Scout both changed the editor file.
  It was only the import lines, so I kept both.
- **Settings not saving in the release apk:** found on the S22, see test 4 above.
  Cause was R8 shrinking, fixed by turning it off for release.
- **Timer leaks:** I wanted proof the timer stops when you leave the screen.
  There's a widget test that leaves a running session, and the test framework
  fails if a timer is left running.

## 6. Known issues

See the list in README.md. The main ones: Session Scout can't see trends,
a running timer isn't restored after the app is killed, landscape and big text
sizes aren't verified yet, and I haven't tried a second physical phone, only an emulator.

## 7. Contribution

I'm the only developer, so all of the code, tests and docs are in my repo under
my account. Commit history: https://github.com/Howflet/Adaptive-Focus-Studio/commits/main

## 8. What I learned

- **Passing tests isn't the same as a working app.** All 56 tests passed, but on
  the S22 the release build couldn't save settings. The cause was R8 shrinking,
  which the tests and the debug build never use. I only found it by restarting
  the real app. Next time I'd install the release APK on a phone early, not at
  the end.
- **Keeping rules out of the widgets paid off.** Because the timer rules and
  Session Scout are plain Dart, I could test them with a fake clock and made-up
  logs without waiting real minutes or running the UI.
- **Widget tests with SQLite are fussy.** The database doesn't run on the fake
  test clock, so I needed `tester.runAsync` and a `settle()` helper before the
  tests stopped hanging.
- **Session Scout is small and honest about it.** The median of three beat the
  25 minute baseline on my six made-up cases, but I wrote the cases myself, so it
  proves little. The 20, 25, 58 counterexample shows what it can't do.
- **The board got behind.** The first cards were late and the commits are bunched
  on two days. Smaller cards and committing as I go would have shown steadier
  progress.
- **What I skipped:** a peer observation (solo project) and a second physical
  phone. I used an emulator for the second environment.
- **If I had more time:** restore a running timer after the app is killed, try
  a window of 5 sessions in Scout, and check landscape and large text.
