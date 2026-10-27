# AI feature: Session Scout

Session Scout is a **rule-based helper**. It is not a trained model and not
generative AI. It runs on the phone, uses no network and no API.

Code: `suggestDuration(logs, mood)` in `lib/helpers/session_scout.dart` (pure
Dart, no widgets). Card: `lib/widgets/scout_card.dart`, shown on the preset
editor (screen 2).

## Benefit

When making a preset it's hard to know how long to plan. Scout suggests a
starting length based on how long I actually finished sessions in the same mood.
It's a starting point, not a promise.

## Inputs and units

From the saved SessionLog rows:

- `completedSeconds`, converted to minutes (rounded)
- `moodTagSnapshot`, to match the mood chosen in the editor
- `status`, only `finished` counts
- `startedAt`, to find the 3 most recent

Logs that are cancelled or have 0 completed seconds are ignored. Nothing else is
read and nothing new is collected.

## Method

1. Keep finished logs with the same mood and more than 0 completed time.
2. Take the 3 most recent.
3. If there are fewer than 3, show "Not enough history yet (N of 3)" and make no
   suggestion.
4. Otherwise the suggestion is the **median** of the three, in minutes, then kept
   between 10 and 60 minutes. If it was kept (clamped), the card says so.

The card shows the reason, for example: "Suggests 25 min: median of your last 3
finished Calm sessions (20, 25, 30)."

**Why median and not mean:** one unusually long or short session moves the mean
a lot more than the median. With 20, 25 and 58 the median is 25 and the mean is
34.

**Alternative I compared against:** the mean of the last 3.

**Baseline:** a fixed 25 minutes (the app's default).

## User control

- **Apply** only puts the number in the slider. Nothing is saved until the user
  presses Save, and the user can still move the slider first.
- **Dismiss** hides the card. Changing the mood brings it back.
- The helper never starts a timer and never saves a record by itself.
- With not enough history there are no buttons, just the message.
- Works fully offline, nothing leaves the device.

## Cases

All cases use made-up data from `test/fixtures/scout_fixtures.dart` and are
automated tests (`test/session_scout_test.dart` and `test/scout_card_test.dart`).
"Actual" is what the tests got when I ran them, all passing.

| Case | Input (same mood) | Expected | Actual | Result |
|---|---|---|---|---|
| C1 normal | 20, 30, 25 min, all finished | Suggests 25 with the reason. If the next session is 22, helper and baseline are both off by 3 | 25, reason text matches, both off by 3 | pass |
| C2 not enough data | only 2 finished sessions | "Not enough history yet (2 of 3)", no suggestion | same, no Apply button shown | pass |
| C3 invalid input | a log with 0 completed seconds and a cancelled log | both ignored; with only 2 valid logs it shows not enough history, with a third valid log it uses only the valid ones | 2 matching found; with a third valid one it used 20, 25, 35 and suggested 25 | pass |
| C4 boundary | 5, 6, 7 min and separately 90, 95, 100 min | clamped to 10 and to 60 and the card says so | 10 (median 6) and 60 (median 95), message says "Kept between 10 and 60" | pass |
| C5 counterexample | 20, 25, 58 min, next session 55 | suggests 25, off by 30 | 25, off by 30 (mean 34 would be off by 21) | pass |
| C6 change of input | change the mood, or edit a log's time | the suggestion updates right away | changing the mood in the editor gives "Not enough history yet (0 of 3)" for a mood with no logs; editing log times changes the median | pass |
| C7 repeated taps | tap Apply five times, then Save once | exactly one preset saved, no log created | 1 new preset saved at 25 min, log count unchanged | pass |

## Evaluation

I measured the absolute error in minutes between the suggestion and the next
real finished session, for Scout and for the 25 minute baseline.

| Last 3 sessions (min) | Next session | Scout | Scout error | Baseline error |
|---|---|---|---|---|
| 20, 30, 25 | 22 | 25 | 3 | 3 |
| 40, 45, 50 | 48 | 45 | 3 | 23 |
| 15, 20, 25 | 20 | 20 | 0 | 5 |
| 30, 35, 30 | 33 | 30 | 3 | 8 |
| 55, 60, 50 | 52 | 55 | 3 | 27 |
| 20, 25, 58 | 55 | 25 | 30 | 30 |

Sample size: 6 cases. **Mean absolute error: Scout 7.0 min, baseline 16.0 min.**
(Total 42 vs 96.)

Limits of this: the data is made up by me, so it only shows the rule behaves the
way I expect. It is a demonstration, not proof it would work for anyone else.
Scout does better here partly because most of my made-up examples are steady
sessions, where "the last 3" is a good guess. I didn't hold out separate test
data, and I chose the rule (median of 3) in the proposal before I wrote these
cases, but I also wrote the cases, so they aren't independent.

## Counterexample

Sessions of 20, 25 and 58 minutes give a median of 25. If the next real session
is 55 minutes, the suggestion is off by 30. A median of three can't see a trend
toward longer sessions, and it looks the same as the baseline here.

## Limitation / possible revision

The window of 3 is small and ignores trends. I could try a window of 5. I did
not build or test that, so it's just an idea for now.

## Responsible use

Scout says nothing about attention, focus ability or health, and shows no
confidence percentages. It only reflects the user's own past sessions.
