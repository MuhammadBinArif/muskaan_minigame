# Phase 4L.3A historical smile analytics foundation

## Existing architecture audit

Completed rounds are stored in the existing SQLite `game_records` table. Stable ownership is `game_records.player_id`; the mutable display-name and avatar snapshots and smile summaries are in the one-to-one `session_details` row. Phase 4L.2B added nullable calibrated fields: attempted status, valid sample count, average intensity, peak intensity, and observed span. The legacy `smile_score`, `smile_average`, and `smile_peak` fields are gameplay/history compatibility data and are never interpreted as calibrated intensity.

The application has no remote verification flag or server verification service. Its existing official local-result boundary is a persisted completed `GameSessionState.results` row (`state = SessionState.completed`) with an end timestamp. Analytics preserves that boundary. Rows in active, paused, ready, or game-over state are excluded. NULL ownership stays unassigned and is excluded from every player query.

`GameRecordsRepositoryImpl` remains the sole result repository. No database, profile store, background service, or analytics persistence layer was added. Profile name and avatar changes cannot affect ownership because all queries use the immutable player ID.

## Query strategy

`getPlayerSmileHistory` performs one bounded SQLite inner join between `game_records` and `session_details`. It requires an exact stable player ID and filters for completed/end-dated rows with a genuine attempted measurement, positive sample count, and all four calibrated values present. It supports inclusive completion-date bounds, newest/oldest ordering, offset pagination, and a maximum page size of 100.

The query does not load full history or query during widget rebuilds. The local database is expected to remain small and the existing schema has no player/time composite index. This increment keeps schema version 4 and avoids a migration solely for a speculative index. If measured history grows enough to make scans material, a future migration can add an owner/state/end-time index using device profiling evidence.

Retries use the existing primary result ID and upsert transaction, so the same result cannot produce multiple history rows. The domain aggregator also deduplicates by result ID as defense against non-repository input.

## Analytics definitions

An eligible historical round has a verified local completion, exact owner, positive valid-observation count, finite average and peak calibrated intensity in 0–100, average no greater than peak, non-negative span, and completion timestamp.

- **Highest recorded average:** maximum persisted round average; ties choose the earliest completion and then the smallest result ID.
- **Highest recorded peak:** maximum persisted round peak with the same tie rule.
- **Average of round averages:** sum of eligible round averages divided by eligible round count. Every round has equal weight. No observation-weighted average is implemented.
- **Most recent round:** latest completion, with result ID as deterministic tie break.
- **Timestamp boundaries:** earliest and latest eligible completion timestamps.
- **Excluded invalid count:** number of supplied domain rounds rejected for invalid measurement fields; repository queries normally exclude them before aggregation.
- **Round comparison:** the second round is classified as lower, equal, or higher for average, peak, count, and observed span. Both rounds must be valid and have the same stable player ID.

No eligible data returns `null` for personal bests and progress. Touch-only, missing, corrupt, legacy gameplay-only, NULL-owner, and incomplete records are not converted to zero.

## Historical compatibility, privacy, and performance

Historical rows are read only. No ownership, score, timestamp, legacy metric, profile snapshot, or verification state is rewritten. Analytics remains on device. It stores no new face data, images, frames, embeddings, or measurements and exposes nothing to ads or analytics SDKs. Smile intensity remains a calibrated facial observation, not a measure of happiness.

## Automated evidence

Focused tests cover owner isolation, NULL ownership, completion filtering, missing/Touch-only data, date range, ordering, pagination, retry idempotency, personal bests, deterministic ties, empty data, duplicate IDs, progress formulas and timestamp bounds, and same/cross-player comparisons. Real in-memory SQLite is used for repository tests.

Flutter execution and analysis remain dependent on a usable Flutter SDK. In this environment SDK bootstrap is blocked by the artifact host network policy; supplemental formatting, syntax, security, and diff checks are reported separately in the final response.

## Remaining limitations

- There is no remote verification mechanism; “verified” means the existing locally completed-result boundary.
- No charts, progress UI, observation-weighted average, cloud sync, or global analytics were added.
- A composite history index is deferred until actual database size and query profiling justify a schema migration.
- Synthetic/in-memory SQLite tests do not replace physical-device database, camera, or lifecycle validation.
