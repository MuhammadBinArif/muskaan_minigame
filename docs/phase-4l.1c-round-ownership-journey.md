# Phase 4L.1C mandatory round ownership report

> Final lifecycle, navigation and leaderboard propagation coverage was added in Phase 4L.1D. See `phase-4l.1d-final-identity-verification.md`.

Date: 9 November 2026 (Asia/Karachi). Work remains local and uncommitted. No physical device was used.

## 1. New-round creation audit

**PASS.** Production creates rounds only through `GameSessionNotifier.startGame`, called by the Smile and Touch branches of `GameplayScreen._startGame`. Replay returns through countdown/gameplay and uses the same method. Direct factory calls were confined to domain/repository tests and were updated to deterministic owned fixtures. Results' empty UI state now uses a direct nonpersisted historical-style value and does not invoke the new-round factory.

## 2. Mandatory ownership enforcement

**PASS (source); Flutter execution BLOCKED.** `GameSessionRecord.create` now requires non-null `playerId`, `playerName` and `playerAvatar`. It validates the stable ID before returning. Empty IDs fail validation and null is rejected by Dart's required non-null type boundary. `GameSessionNotifier` requires a profile callback; unavailable profile state throws before any round/session mutation. `GameRecordsRepository.saveSession` rejects unowned values, providing a second persistence boundary.

The nullable regular `GameSessionRecord` constructor remains available for database hydration and honest historical/unavailable presentation. It is no longer used to create or save new gameplay rounds.

## 3. Ownership immutability

**PASS (source); lifecycle tests authored but runtime BLOCKED.** The controller creates one immutable owned session before gameplay begins. `activePlayerId` exposes the captured value for assertions. Pause, resume, Touch/Smile provider changes, camera startup failure, game-over and navigation do not replace that session. Completion copies `_session.playerId`; current profile lookup can refresh display fields only for the same ID. Persistence and retry receive the already completed record and never read profile state.

## 4. Actual Player A → Player B test

**PASS (test design/source); execution BLOCKED.** The integration test uses a real in-memory `GameDatabase`, `PlayerProfileRepository`, `playerProfileProvider`, `GameRecordsRepositoryImpl`, and `GameSessionNotifier` wired to that provider. It:

1. Loads and persists Player A.
2. Starts, pauses and resumes an owned round.
3. Installs a SQLite `BEFORE INSERT` failure trigger.
4. Completes the round and confirms the first save failed.
5. Drops the trigger, saves Player B through the real profile repository, and reloads the production provider.
6. Retries concurrently.
7. Reads SQLite and asserts one row with Player A's ID and the original result ID, score, start timestamp and completion state.

This replaces the earlier standalone mutable-variable retry simulation.

## 5. Retry and duplicate prevention

**PASS (source); execution BLOCKED.** `_saveInFlight` coalesces concurrent attempts and `_hasPersisted` suppresses later attempts. The retry uses the same `completedRecord`; no callback to the profile provider exists in `_saveRecord` or the records repository. Tests assert exactly one database row after concurrent retry.

## 6. Lifecycle, control and navigation coverage

| Path | Status | Evidence |
| --- | --- | --- |
| Pause/resume | PASS / NOT TESTED | Explicit `activePlayerId` assertions authored |
| Touch → Smile / Smile → Touch state | PASS / NOT TESTED | Mode provider changes leave active session unchanged; assertions authored |
| Camera startup failure | PASS / NOT TESTED | Throwing camera provider test asserts captured owner remains |
| Camera interruption | PASS (source) / NOT TESTED | Tracking invalidation never mutates the session; device execution unavailable |
| Game-over | PASS / NOT TESTED | Completed record copies original owner; integration assertion authored |
| Game Over → Results | PASS (source) / NOT TESTED | Router passes `completedRecord` unchanged; widget execution blocked |

Direct navigation to Game Over/Results without a round now receives a nullable unavailable record. It no longer creates an unowned synthetic round.

## 7. Results ownership and avatar behavior

**PASS (source); widget execution BLOCKED.** `PlayerIdentity` uses the live authoritative profile name/avatar only when its stable ID exactly matches the result owner. Different owners use their stored round snapshot. Null ownership displays `◯ Player not recorded`. Missing supported identity data displays `Player unavailable`. Tests cover current-ID live updates, immutable snapshot selection, different owners and unassigned history.

Avatar snapshots remain in result metadata because this local app stores only one live profile; without snapshots it could not render a different known owner honestly. They are immutable historical metadata, not a second mutable avatar store.

## 8. Demo/local leaderboard

**PASS (source); widget execution BLOCKED.** Challenges remains labelled “Local rounds on this device · not a global leaderboard,” and the dedicated leaderboard says “Leaderboard on this device.” An exact current-player ID match resolves the authoritative current name/avatar reactively. Other rows use their own snapshot or unknown-owner fallback. A widget test changes the current name/avatar and asserts the local entry updates.

## 9. Authoritative avatar architecture

**PASS.** Repository audit still finds one mutable persisted avatar: `PlayerProfile.avatar` in `PlayerProfileRepository`. `ProfileAvatarRepository` is a reactive adapter and owns no persistence. Profile, Avatar Studio, Flame gameplay, Results and leaderboard use this view under stable-ID rules. Studio save/reset and file-backed restoration coverage remain present. No SharedPreferences avatar key, second avatar database table or remote store was added.

## 10. Files modified in this increment

- `lib/core/domain/game_session.dart`
- `lib/core/providers/game_session_provider.dart`
- `lib/features/game/data/records_repository.dart`
- `lib/app/router/app_router.dart`
- `lib/features/results/presentation/screens/results_screen.dart`
- `lib/features/game/presentation/screen/game_over_screen.dart`
- `test/support/player_fixture.dart`
- `test/session_regression_test.dart`
- `test/records_repository_test.dart`
- `test/profile/player_profile_test.dart`
- `test/profile/identity_flow_test.dart`
- `test/tracking/mouth_tracking_controller_test.dart`
- `test/game/avatar_presentation_test.dart`
- `test/app_navigation_test.dart`
- Phase reports under `docs/`

## 11. Verification

| Check | Status | Exact result |
| --- | --- | --- |
| Supplemental Dart formatter | PASS | 42 changed/new Dart files formatted; final repeat had no pending changes |
| Dart syntax parser | PASS | Zero syntax errors across `lib` and `test` |
| `git diff --check` | PASS | No whitespace errors |
| Security/manifest checks | PASS | Existing manifest, plist/ATS, signing and symbol checks passed |
| Python tooling tests | PASS | 3/3 passed |
| SQLite v2→v3 ownership smoke | PASS | IDs/scores/state retained, null remained null, trusted owner copied, integrity `ok` |
| New Flutter ownership/avatar tests | BLOCKED | Authored but not executed because no usable Flutter/Dart SDK |
| `flutter analyze` | BLOCKED | SDK bootstrap receives proxy CONNECT 403 |
| `flutter test` | BLOCKED | Same SDK artifact restriction; no Flutter pass claim |
| Physical Android/iOS validation | NOT TESTED | No device available |

## 12. Acceptance status and remaining blockers

- **PASS:** every new domain round requires validated ownership.
- **PASS:** controller and repository boundaries reject unowned new results.
- **PASS:** historical null ownership remains readable and honest.
- **PASS:** retry never fetches or changes ownership.
- **PASS:** Results/leaderboard avatar substitution follows stable-ID matching.
- **PASS:** no duplicate avatar persistence or backend was added.
- **BLOCKED:** Flutter compilation, analyzer, migration test execution and widget/integration execution.
- **NOT TESTED:** physical camera interruption, rendering and lifecycle behavior.

The implementation cannot be declared runtime-validated until the Flutter SDK is available and the full suite passes.
