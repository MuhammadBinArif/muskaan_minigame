# Phase 4L.2B gameplay and Results integration

Date: 9 November 2026 (Asia/Karachi). Changes are local and uncommitted. No physical device was used.

## Audit and integration design

The authoritative flow is now:

`ML Kit smilingProbability` → `FaceTrackingObservation` → `MouthTrackingController` → Phase 4L.2A `SmileMeasurementEngine` → `MouthTrackingState.smile` → gameplay HUD / round collector / Smile Spotlight → immutable result → SQLite `session_details` → Results.

There is one engine and one tracking pipeline. `smileCalibrationProvider` supplies optional genuine neutral/natural-smile probability references to the existing controller. It defaults to null because this checkout has no `smile_calibration_store.dart`, no persisted probability references, and no approved probability-calibration capture flow. The existing `CalibrationConfig` remains mouth-openness calibration and is not reinterpreted.

## Gameplay behavior

Smile mode displays the Phase 4L.2A smoothed calibrated value as `Smile Intensity N%`. Valid raw probability without probability calibration displays `Smile intensity unavailable · calibration required`. Missing face, stale measurement and camera errors retain their existing explicit states. Touch-Only says smile measurement is unavailable and never fabricates a value.

The UI observes the existing tracking notifier. No polling, second engine or persistence-per-frame was added. Mouth-open triggering, pending catches, collision windows, scoring and object spawning are unchanged.

## Round collection lifecycle

Each new owned round constructs one `SmileRoundStatisticsCollector` with the captured player ID and immutable result ID. Only measurements delivered while the session is playing reach it. The collector accepts genuine fresh calibrated measurements, deduplicates timestamps and stores constant-size count/sum/peak/first/last state.

Pause stops collection because `state.isPlaying` is false. Tracking stop, camera interruption and Smile/Touch changes invalidate/reset engine smoothing; rejected and uncalibrated observations do not enter statistics. A new round creates a new collector. Result completion snapshots the collector once, and failed writes/retries reuse the immutable completed record without collecting or duplicating samples.

Persisted definitions:

- valid observation count: accepted raw calibrated samples;
- average intensity: arithmetic mean of raw calibrated intensities on `[0,100]`;
- peak intensity: maximum raw calibrated intensity;
- observation span: milliseconds between first and last accepted samples, not continuous coverage.

## Results and historical behavior

Results has a separate **Smile Measurements** section. Genuine new measurements show average, peak, valid count and observation span. A new round that never attempted measurement reports that none were collected. A round with valid raw observations but no usable probability calibration reports calibration/observations unavailable. Historical rows show that calibrated measurements were not recorded.

Legacy `smile_score`, raw probability average/peak and gameplay values remain unchanged and are never relabelled as calibrated intensity. Empty/unavailable values are not converted to zero or 92%.

## Smile Spotlight

Smile Spotlight consumes `mouthTrackingProvider`, the same authoritative source as gameplay. Its live ring/value uses smoothed calibrated intensity only. An explicit measurement session uses the Phase 4L.2A bounded collector to label Average Smile Intensity and Peak Smile Intensity correctly. Without genuine calibration or accepted samples, all intensity values remain unavailable. Copy states explicitly that this is not an emotion measurement, and no face images are stored.

## Database migration

Schema version is 4. Five nullable columns are added to `session_details`:

- `calibrated_smile_attempted`
- `calibrated_smile_samples`
- `calibrated_smile_average`
- `calibrated_smile_peak`
- `calibrated_smile_span_ms`

Version-2 and version-3 upgrades use `ALTER TABLE`; version-1 upgrades create the current table directly. Historical values default to null, so they are unavailable rather than reinterpreted. Player ID remains in `game_records.player_id`. Save, ownership and statistics metadata remain in one transaction. Stable result IDs and completed records preserve retry idempotency.

## Privacy, ownership and performance

- Processing remains on-device; no frames, face images, embeddings or observation histories are stored.
- No calibration/measurement analytics or advertising access was added.
- Statistics stay attached to the original immutable result and player ID during retry.
- Engine and collectors are bounded constant-memory components.
- No dependency, FFI, backend or remote identity change was introduced.

## Tests and verification

Focused coverage includes 13 Phase 4L.2A domain tests and one synthetic tracking-pipeline test. Existing profile/result tests now assert calibrated count, average and peak persistence. Migration coverage checks historical calibrated fields remain null. Results widget coverage asserts genuine average/peak/count/span rendering, and navigation tests assert unavailable Spotlight/Results states.

Repository-wide source discovery reports 241 Flutter `test`/`testWidgets` declarations. This is a source count, not execution.

| Check | Status | Outcome |
| --- | --- | --- |
| Domain and pipeline tests | BLOCKED | Authored; Flutter SDK cannot bootstrap |
| Gameplay/Results/Spotlight widget tests | BLOCKED | Authored; Flutter SDK cannot bootstrap |
| Migration and retry tests | BLOCKED | Authored; Flutter SDK cannot bootstrap |
| Full `flutter test` | BLOCKED | Proxy CONNECT 403 downloading Flutter Dart SDK |
| `flutter analyze` | BLOCKED | Same SDK restriction |
| Supplemental Dart formatting | PASS | 44 changed/new Dart files; final repeat has no changes |
| Dart syntax parsing | PASS | Zero syntax errors |
| `git diff --check` | PASS | No whitespace errors |
| Security/manifest checks | PASS | Existing checks passed |
| Python tooling tests | PASS | 3/3 passed |
| Physical-device validation | NOT TESTED | No Android/iOS device available |

## Remaining limitations

- Production calibrated intensity remains unavailable until genuine neutral/natural-smile probability references can be captured and persisted through an approved product flow.
- Flutter compilation and runtime behavior remain unverified because the SDK artifact host is blocked.
- Observation span is not continuous camera coverage or a time-weighted average.
- Fake-camera tests do not validate physical camera permissions, drivers, thermal behavior or OS interruption.
