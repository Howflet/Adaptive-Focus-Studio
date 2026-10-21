# Adaptive Focus Studio

Offline study timer app for my Mobile App Dev project 1 (GSU, Fall 2026).
You save presets for the stuff you study, run a timer, and see planned vs
completed time afterwards. Everything is stored on the phone (SQLite +
SharedPreferences). No accounts, no cloud.

Made by Howard Fletcher.

## Status

Just getting started. Repo + Flutter project are set up and the database
helper for presets is in. Screens come next.

## Running it

1. Install Flutter (stable)
2. `flutter pub get`
3. `flutter run` with an emulator or phone plugged in

## Folders

- `lib/screens` - the 5 screens
- `lib/widgets` - small reusable widgets
- `lib/data` - database helper
- `lib/models` - FocusPreset, SessionLog
- `lib/helpers` - Session Scout (later)
- `test` - tests

## TODO

- setup steps, user guide, ARCHITECTURE.md, AI_FEATURE.md
