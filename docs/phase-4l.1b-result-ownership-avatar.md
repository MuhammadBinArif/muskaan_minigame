# Phase 4L.1B result ownership and avatar report

> Mandatory new-round enforcement and the final live-avatar semantics were completed in Phase 4L.1C. See `phase-4l.1c-round-ownership-journey.md`.

Date: 9 November 2026. Work is local and uncommitted. No physical device was used.

## 1. Database schema and migration

**PASS (source and SQLite smoke); Flutter migration test NOT TESTED.** The database schema is version 3. Migration adds nullable `player_id` directly to `game_records`, preserving its existing primary key, scores, timestamps, completion state and every other generated column. Version-2 rows copy ownership only from an already non-null `session_details.player_id`. Rows without that evidence remain `NULL`. Version-1 upgrades create the extension tables and leave all historical ownership null.

Version 3 writes ownership only to `game_records.player_id`. The older extension column remains physically present for SQLite compatibility but is no longer written or read. The migration smoke fixture retained `(id, score, state) = (7, 100, 5)` with null ownership, retained `(8, 250, 5)`, copied its existing trusted ID, and returned `PRAGMA integrity_check = ok`.

This repository has no separate verified-status column or remote verification mechanism. The existing completion `state` and `is_new_best` fields are preserved byte-for-byte; no verification claim was introduced.

## 2. Historical ownership

**PASS.** Historical rows are never assigned to the current profile. Null ownership is returned as null in `GameSessionRecord` and displayed as “Player not recorded.” A nonmatching owned result uses its stored name/avatar snapshot. It never substitutes the current local profile.

## 3. Round identity capture and lifetime

**PASS (source); runtime NOT TESTED.** `GameSessionNotifier.startGame` reads the authoritative profile once and creates the round's immutable `GameSessionRecord` with its stable ID, name and avatar snapshot. Production gameplay refuses to start if profile state is loading or unavailable. The record survives pause/resume, input-mode changes, game-over and Results navigation. Completion may refresh name/avatar only when the current stable ID still matches; it never changes `playerId`.

## 4. Persistence and retry

**PASS (source); automated Flutter execution BLOCKED.** Game-over publishes one completed immutable record. The first write and every retry use that record. Neither `_saveRecord` nor the repository reads profile state. Concurrent retry calls share `_saveInFlight`; after success `_hasPersisted` suppresses duplicates. A new deterministic test starts as Player A, fails the first write, switches the active profile to Player B, retries concurrently, and asserts the identical object is saved once with Player A's ID and snapshots.

## 5. Results display

**PASS (source); widget execution BLOCKED.** Results and game-over explicitly request the immutable round snapshot from `PlayerIdentity`, even when the current profile has the same ID. An unassigned record says “Player not recorded.” An owned record uses only its stored snapshot, with “Player unavailable” if no supported identity data exists. The local leaderboard may resolve the live profile only for an exact stable-ID match, so current profile data is never presented as ownership evidence for another ID.

## 6. Avatar architecture

**PASS, based on repository audit.** No SharedPreferences avatar persistence implementation exists in this checkout. The older Flame avatar class is a renderer and reaction state machine, not a store. The only persisted avatar is `PlayerProfile.avatar` in `PlayerProfileRepository`; `ProfileAvatarRepository` is a reactive presentation adapter over that field and owns no storage.

Creating a SharedPreferences store would introduce the duplicate persistence prohibited by this increment. The existing database profile therefore remains authoritative. Result avatar snapshots are retained because they prevent a later avatar edit from being presented as historical evidence. They are immutable result metadata, not a mutable avatar store.

## 7. Unified reactive avatar surfaces

**PASS (source); runtime NOT TESTED.** Profile and Avatar Studio write through `PlayerProfileController`; the adapter invalidates reactively. Profile, Avatar Studio preview, Flame gameplay, Results/game-over and the current local leaderboard entry consume that profile or the result snapshot under the stable-ID rules above. Avatar Studio now exposes reset to the fallback ninja avatar. File-backed profile tests cover restart restoration; widget coverage includes Studio reset.

## 8. Privacy and boundaries

**PASS (source audit).** Identity/avatar data remains local. No backend, remote account, facial data, camera storage, ad identity sharing or analytics was added. The leaderboard remains explicitly local and not server verified.

## 9. Files changed in this increment

- `lib/features/game/data/game_database.dart`
- `lib/features/game/data/records_repository.dart`
- `lib/features/profile/presentation/widgets/player_identity.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `test/profile/profile_migration_test.dart`
- `test/profile/identity_flow_test.dart`
- `test/session_regression_test.dart`
- Phase reports under `docs/`

## 10. Verification

| Requirement/check | Status | Evidence |
| --- | --- | --- |
| Schema v2 → v3 migration | PASS / NOT TESTED | Actual SQLite SQL smoke passes; authored Drift fixture could not execute |
| Historical null ownership | PASS | SQL smoke retained null; source maps null without inference |
| IDs, scores, completion state | PASS | SQL smoke retained exact values |
| Valid owned result insertion | PASS / NOT TESTED | Transactional source and tests authored; Flutter execution blocked |
| Capture at round start | PASS | Immutable record creation point audited |
| Pause/resume and control switching | PASS / NOT TESTED | No ownership mutation on these paths; runtime blocked |
| Failure/profile-change/retry | PASS / NOT TESTED | Deterministic test authored; runtime blocked |
| Duplicate retry suppression | PASS / NOT TESTED | `_saveInFlight`/`_hasPersisted` and assertions present; runtime blocked |
| Historical Results fallback | PASS / NOT TESTED | Source uses “Player not recorded”; widget runtime blocked |
| Avatar restoration/reactivity/reset | PASS / NOT TESTED | File/widget tests authored; runtime blocked |
| Supplemental Dart formatting | PASS | 39 changed/new Dart files formatted |
| Dart syntax parsing | PASS | Zero syntax errors |
| `git diff --check` | PASS | No whitespace errors |
| Security/manifest checks | PASS | Existing checks passed |
| `flutter analyze` | BLOCKED | SDK bootstrap receives proxy CONNECT 403 |
| `flutter test` | BLOCKED | Same unavailable Flutter/Dart SDK; no Flutter pass claim |
| Physical-device validation | NOT TESTED | No device available |

## 11. Remaining limitations

- Flutter type analysis and test execution remain blocked by the SDK artifact network policy.
- The application supports one local profile and local history, not remote/multiple accounts.
- The deprecated version-2 `session_details.player_id` column remains physically present for compatibility but has no runtime authority after migration.
- Physical rendering, database upgrade and lifecycle behavior remain unverified on Android/iOS hardware.
