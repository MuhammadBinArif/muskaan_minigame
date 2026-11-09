# Phase 4L.3B Smile Analytics dashboard

## Data flow and reused architecture

The dashboard uses the existing `playerProfileProvider` for the current stable player ID, display name, and avatar. `playerSmileHistoryProvider` keys each query by stable ID and selected range, then calls the Phase 4L.3A `GameRecordsRepository.getPlayerSmileHistory` boundary. The repository remains responsible for ownership, completion, validity, date, order, and 100-row bounds. `PlayerSmileAnalytics` remains the only personal-best, summary, deduplication, and comparison engine. Its `excludedInvalidCount` remains available on progress summaries; repository-backed dashboard queries normally report zero because invalid rows are rejected at the data boundary.

No second repository, database table, persisted aggregate, or chart dependency was introduced. Results navigation re-reads the original record and verifies both its owner and the still-active profile ID before opening `ResultsScreen`.

## Dashboard structure

The new `/smile-analytics` route is accessible from Profile. It presents:

- Current authoritative avatar and display name.
- Measured-round count, unweighted average of round averages, highest peak, and most recent measured round.
- An interactive chronological chart with a visible 0–100 scale and Average/Peak selector.
- Exact date, value, and result ID after selecting a chart point.
- Personal-best cards with source date and round ID.
- Two-round selection with neutral Higher, Lower, and Unchanged comparison labels.
- Up to 100 recent eligible rounds with average, peak, valid observation count, and explicitly defined observed span.

The chart plots one point for each genuine persisted measurement. It neither inserts missing rounds nor converts unavailable values to zero. A semantics label identifies the metric, scale, and point count without relying on color.

## Date ranges and identity changes

The 7, 30, and 90-day filters pass inclusive completion timestamp bounds into SQLite. All history passes no lower bound. Changing a range creates a new provider key and resets chart and comparison selection, keeping overview, chart, bests, comparison candidates, and history consistent.

Profile replacement changes the stable-ID component of the provider key. Riverpod then discards the previous query from the active widget and requests only the replacement player's rows. Display names are never query keys.

## Loading, error, and empty behavior

Loading displays an explicit progress state. Repository failures display a retryable error and never masquerade as empty history. A successful empty query displays an unavailable state and never shows a zero personal best. Pull-to-refresh invalidates only the active player/range query.

## Smile Spotlight integration

Smile Spotlight keeps its current-session collector and live camera measurement separate. A new historical card reads the same 30-day stable-ID provider used by the dashboard and presents genuine eligible-round count, average of round averages, and highest peak. Missing history and database failures have distinct messages. No demo value, emotion label, camera frame, or face image is introduced.

## Performance, accessibility, and privacy

Queries remain bounded to 100 rows and run only when the stable player ID, range, or explicit refresh changes. Aggregation is deterministic and in memory over that bounded page. The custom chart avoids another package and repaints only when its points or selection changes.

Controls have visible text or semantic labels, chart meaning is announced independently of color, comparison states use words, history selection has a semantic label, and the screen uses SafeArea plus a scrolling layout. Analytics remains local and is not exposed to advertising or analytics SDKs. Smile intensity is described as a calibrated facial observation rather than happiness or emotion.

## Automated coverage

Tests cover exact average and peak chart series, chronological ordering, invalid-value exclusion, genuine SQLite-backed dashboard values, range controls, bounded round details, empty state, and distinct loading/database-error states. The existing Phase 4L.3A tests continue to cover repository isolation, date filtering, pagination, retry deduplication, bests, summaries, and comparison rules.

## Remaining limitations

- “All” displays the latest bounded 100 eligible measurements; it does not load an unbounded database history.
- The chart exposes first/last date labels and an exact selected-point tooltip rather than labeling every dense point.
- Local completion is the app's existing verification boundary; no server verification exists.
- Physical-device rendering, large accessibility text, SQLite behavior, and camera lifecycle still require hardware validation.
