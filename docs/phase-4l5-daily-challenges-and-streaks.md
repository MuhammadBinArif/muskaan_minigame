# Phase 4L.5 daily challenges and streaks

## Architecture audit

The former Challenges screen used fixed demonstration goals, progress, reward points, timers, and leaderboard copy. None of those values came from persisted results. The route now uses the stable player profile, `GameRecordsRepository`, calibrated smile summaries, Phase 4L.4 achievements, and the existing SQLite database.

The implementation adds a pure daily challenge generator/evaluator and streak calculator, a small assignment repository, an application service, and a Riverpod presentation boundary. It does not duplicate identities, results, analytics, achievements, or avatar state.

## Challenge definitions

The deterministic pool contains:

- Complete one or three verified rounds today.
- Reach 500 verified points in one round.
- Make five successful catches in one round.
- Complete a calibrated measured round.
- Collect 20 valid calibrated observations.
- Reach an 80% calibrated peak intensity.
- Use both Smile and Touch input during verified play.
- Accumulate two distinct verified activity dates.
- Beat the verified score best that existed before today.

Three challenges are selected per player/day. Smile definitions are excluded from new assignments until that player has genuine calibrated measurement evidence. If a persisted smile assignment later lacks usable evidence, it is displayed as unavailable rather than zero or nearly complete. Touch-only gameplay can complete gameplay, catch, score, round, date, best-score, and mode-variety goals without camera initialization.

## Deterministic assignment and date strategy

Selection uses a stable FNV-style hash of `stable player ID | effective date key` and a deterministic pool walk. It contains no runtime randomness. Assignments are persisted with player ID, `yyyy-MM-dd` date key, timezone offset, and UTC creation timestamp. Reopening or restarting reads the same rows.

The requested date is the device-local calendar date reconstructed from the current UTC instant plus its current timezone offset. `player_challenge_clock.latest_date_key` is monotonic: an earlier requested date cannot roll assignments backward or create another set for an already passed day. Forward local dates create a new set. Assignment rows have a composite primary key, preventing duplicate rerolls.

Device time is not a security boundary. A user controlling the clock can eventually advance local dates; without a trusted server the app cannot distinguish deliberate changes from travel or genuine elapsed days. The monotonic key prevents backward farming and repeated screen-open rerolls while avoiding any claim of tamper-proof time.

## Result metadata and schema v6

Schema v6 adds nullable immutable result metadata to `session_details`:

- `used_smile_mode`
- `used_touch_mode`
- `completion_timezone_offset_minutes`

Historical rows remain NULL and are never guessed. New rounds mark every input mode used, including in-round switches. Completion timezone offset is restricted to the real-world UTC offset range.

It also adds:

- `daily_challenge_assignments`, keyed by player/date/challenge.
- `player_challenge_clock`, keyed by player.

Progress and streak counters are intentionally derived from authoritative completed result IDs. They are not duplicated mutable counters. The v5-to-v6 migration preserves results and achievement unlocks and adds nullable metadata and assignment tables.

## Progress and retry behavior

Only stable-owner records in `GameSessionState.results` with a completion timestamp count. Result IDs are deduplicated. NULL owners, other players, incomplete/game-over rows, legacy gameplay smile values, and invalid calibrated measurements are excluded.

The engagement provider is invalidated only after result persistence succeeds. Failed writes do not affect progress. Retrying the immutable result replaces the same result ID, so it cannot increment round, observation, activity-day, mode, or streak progress twice. UI progress is clamped to its target.

## Streak definition

Each unique verified activity date counts once. The date is reconstructed using the offset captured when that result completed; historical rows without an offset use UTC without inventing a local offset.

- Consecutive date keys increase the run.
- Multiple same-day results count once.
- Current streak remains active when the latest activity is today or yesterday.
- A larger gap resets current streak to zero.
- Longest streak is the maximum consecutive run in all eligible history.
- Delayed persistence uses the immutable completion timestamp, not write time.

This approach handles midnight and daylight-saving transitions as calendar dates rather than 24-hour durations. Timezone travel uses each result's completion offset.

## UI, rewards, and privacy

The Challenges screen shows current identity/avatar, three assignments, exact progress, unavailable and completed states, current/longest streaks, effective date, reset explanation, cosmetic badges, loading/error/empty states, pull-to-refresh, and an Achievements entry point. Profile also links to Daily Challenges. The legacy fabricated challenge-detail route redirects to the verified daily screen.

Badges are cosmetic recognition only. There are no points, paid unlocks, randomized rewards, gameplay advantages, push notifications, notification permission requests, cloud services, or advertising hooks. All data remains local. Smile intensity is never labeled as emotion or happiness.

## Automated coverage

Domain tests cover deterministic assignment, player separation, smile-aware pools, offset/midnight keys, every progress family, owner/state/result-ID filtering, target bounds, personal bests, same-day deduplication, consecutive streaks, missing-day reset, and longest streak. Real SQLite tests cover restart restoration, independent players, forward dates, backward-clock protection, schema tables, and integrity. Migration coverage includes v5 results/achievement preservation and nullable engagement metadata. Widget regression coverage uses deterministic provider data and rejects the former fabricated leaderboard/rewards.

## Remaining limitations

- Local completion is the existing verification boundary; no server authority exists.
- Device clock and timezone are user-controlled and cannot be made tamper-proof locally.
- Historical mode and timezone fields remain unavailable rather than inferred.
- Physical-device date changes, DST transitions, large text, and long-history performance still require hardware validation.
