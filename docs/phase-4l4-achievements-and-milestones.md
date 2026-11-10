# Phase 4L.4 player achievements and milestones

## Architecture audit and design

The authoritative inputs remain the stable `PlayerProfile.id`, completed `GameSessionRecord` rows, calibrated smile summaries in `session_details`, and the Phase 4L.3 analytics validity rules. The existing Challenges screen contains daily demonstration content and is not used as verified achievement state.

Achievements use a feature-first split:

- `AchievementDefinition` contains stable ID, copy, category, target, and cosmetic badge.
- `AchievementEvaluator` is a pure deterministic eligibility and progress engine.
- `AchievementRepository` owns stable-player SQLite unlock persistence.
- `AchievementService` loads authoritative results and unlocks, evaluates them, and persists only new unlocks.
- `AchievementsScreen` renders definitions and calculated progress without embedding rules.

No identity, result, analytics, avatar, cloud, advertising, or reward store was duplicated.

## Definitions and eligibility

Gameplay badges cover first successful catch, 5/10/25 completed rounds, and a 1,000-point round. Smile badges cover the first genuine calibrated measured round, 5 measured rounds, a 90% calibrated peak, and a later round average exceeding the earlier personal maximum. Progress badges cover beating an earlier score best, scoring above the immediately preceding round, and playing on three distinct UTC calendar days so timezone changes cannot alter eligibility.

Only owned records in `GameSessionState.results` with an end timestamp qualify. Result IDs are deduplicated. NULL owners, another player, game-over/incomplete rows, raw probability fields, legacy `smile_score`, missing calibration, and invalid calibrated values cannot contribute. Missing smile evidence is presented as unavailable rather than zero or nearly complete. Smile intensity is never described as happiness or emotion.

## Persistence and migration

Schema version 5 adds `player_achievements` with composite primary key `(player_id, achievement_id)`, UTC unlock timestamp, and source result foreign key. An owner/time index supports profile reads. The incremental migration uses `CREATE TABLE/INDEX IF NOT EXISTS`, preserves all result/profile/session rows, and is exercised by the existing real v3 fixture through v5.

`INSERT OR IGNORE` makes retries and concurrent duplicate evaluation idempotent. Unlock ownership never follows a display-name or avatar change. Profile replacement naturally uses another stable player key.

## Evaluation lifecycle and unlock notification

`GameSessionNotifier` invokes achievement evaluation only after `saveSession` succeeds. Failed result writes do not evaluate. Retrying the same immutable result can unlock each stable achievement only once. Achievement evaluation and notification run after the save state is cleared; any failure is swallowed at this optional boundary and cannot roll back a result or block Results navigation.

New unlocks are delivered to Results through an ephemeral Riverpod event and cleared before showing a dialog, preventing repeated presentation. The dialog gives a cosmetic badge and has an explicit Continue action. It grants no currency, paid item, randomized reward, gameplay advantage, or advertising reward.

## UI and accessibility

Profile now links to `/achievements`. The screen shows current avatar/name, unlocked badge count, category filters, locked/in-progress/unlocked/unavailable labels, bounded progress bars, and unlock dates. Semantics describe title, status, and numeric progress without relying on color. The layout is SafeArea-protected and scrollable for small screens and larger text.

## Performance and privacy

Evaluation runs after a successful result save or on explicit screen load. It reuses the existing local result repository and holds only immutable summaries. Unlock rows are small and indexed. No camera data, face image, embedding, remote analytics, cloud account, ad targeting, or log of personal measurement history was added.

## Automated coverage

Domain tests cover ownership, completion state, duplicate IDs, gameplay boundaries, genuine/missing smile measurements, smile improvement, score best, comeback, calendar days, and restored unlocks. Real SQLite tests cover restart restoration, retry idempotency, player isolation, NULL/unverified exclusions, schema v5, and result preservation. Widget coverage verifies identity, locked/unavailable presentation, progress definitions, and category filtering.

Flutter execution remains dependent on the unavailable SDK artifact; exact executed and blocked checks are reported in the final response.

## Remaining limitations

- Verification is the existing local completed-result boundary; no server authority exists.
- Historical completed results are valid evidence and may unlock a badge on first evaluation. No rows are rewritten or assigned ownership.
- Unlock dialogs require Results to remain mounted when asynchronous evaluation finishes; unlock persistence is authoritative even if a dialog cannot be shown.
- Physical-device rendering, reduced-motion dialog behavior, timezone changes, and large histories require device profiling and validation.
