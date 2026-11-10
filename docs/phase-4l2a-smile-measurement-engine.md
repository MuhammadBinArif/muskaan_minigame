# Phase 4L.2A smile measurement engine

> Gameplay, Results, Spotlight and nullable result-summary persistence were added in Phase 4L.2B. See `phase-4l2b-gameplay-results-integration.md`.

Date: 9 November 2026 (Asia/Karachi). Changes are local and uncommitted. No physical device was used.

## Existing pipeline audit

The existing production path is:

`CameraService` → `VisionServiceImpl` → ML Kit `Face.smilingProbability` → `FaceTrackingObservation.smileProbability` → `MouthTrackingController` → `SmileMeasurementEngine` → `MouthTrackingState.smile` → live probability UI and raw round aggregation.

ML Kit classification is enabled and processing remains on-device. The observation carries the camera callback timestamp. The controller accepts only a usable single-face observation, expires live values after 500 ms, resets on tracking start/stop and camera teardown, and clears them when the camera stops streaming.

Gameplay catch triggering is a separate path based on calibrated mouth openness through `MouthStateMachine`, pending catch state and collision handling. It does not consume calibrated smile intensity and was not changed.

The existing `CalibrationConfig` and `CalibrationSession` calibrate mouth-closed/open contour geometry, neutral face position and movement range. They do not collect neutral and natural-smile ML probability references. No compatible smile-probability calibration repository or persisted thresholds exist. Reusing mouth thresholds would fabricate personalized intensity, so production calibrated intensity remains explicitly unavailable until a genuine probability calibration flow is approved.

## Domain model

`SmileMeasurement` keeps these values distinct:

- **Raw probability:** the genuine ML Kit value in `[0,1]` with its observation timestamp.
- **Smoothed probability:** a bounded EMA retained for existing live probability presentation.
- **Raw calibrated intensity:** the normalized probability calibration result on a `[0,100]` scale.
- **Smoothed calibrated intensity:** an EMA of valid raw intensity samples, also `[0,100]`.
- **Gameplay trigger:** remains outside this model and continues to use mouth openness.

Unavailable calibrated intensity carries `missingCalibration` or `invalidCalibration`. Rejected observations expose reasons for missing/invalid probability, unreliable tracking, stale/future timestamps, duplicate frames and out-of-order frames.

## Calibration

Given neutral probability `N`, natural-smile probability `R`, and raw observation `P`:

`rawIntensity = clamp((P - N) / (R - N), 0, 1) × 100`

Both references must be finite and within probability bounds, and `R - N` must be at least `0.05` by default. The minimum separation is configurable for deterministic tests. Equal, reversed, nonfinite, out-of-range and insufficiently separated references produce unavailable intensity.

Calling `updateCalibration` clears live values, smoothing and ordering state. The next accepted sample is evaluated only with the new references; recalibration does not require engine reconstruction.

## EMA, freshness and reset behavior

The default EMA alpha is `0.35`:

`smoothed = alpha × current + (1 - alpha) × previous`

Probability and calibrated intensity have separate EMA state. The maximum observation age is 500 ms. Missing, invalid, unreliable, stale and future observations clear live values and smoothing. Duplicate and out-of-order observations are rejected without becoming independent samples; an expired retained value is invalidated. No sample list is stored.

`reset()` clears the last timestamp, probability EMA, intensity EMA and current value. Production tracking already invokes reset on tracking initialization, stop/disposal and calibration updates. Gameplay pause and Smile/Touch switching stop tracking, which reaches the same reset boundary. Camera state loss invalidates live smoothing immediately; stop/recovery resets ordering state.

## Round statistics

`SmileRoundStatisticsCollector` is constructed with one non-empty player ID and one positive round ID. It stores only count, sum, peak and first/last accepted timestamps.

- `validObservationCount`: accepted calibrated observations.
- `averageCalibratedIntensity`: arithmetic mean of valid raw calibrated intensities.
- `peakCalibratedIntensity`: maximum valid raw calibrated intensity.
- `observationSpan`: elapsed time between first and last accepted samples. It is not claimed as continuous camera coverage or time above threshold.

Uncalibrated, invalid, stale, future, duplicate and out-of-order samples are excluded. Empty collectors return unavailable average, peak and span rather than zero or a fabricated percentage. A new player or round requires a distinct collector, preventing cross-round/player state reuse by construction.

The collector is domain preparation only. It is not wired into the database or Results UI in this phase. No schema migration is proposed until product semantics for persisted calibrated statistics and a real smile-probability calibration flow are approved.

## Privacy, storage and performance

- Camera frames and facial observations stay on-device.
- No images, landmarks, embeddings, raw probability history or calibration values are logged or uploaded.
- No analytics, advertising access, dependency, FFI or model change was added.
- Engine and collector memory are constant-size and processing is constant-time per observation.
- Player identity and result ownership code is unchanged.

## Tests and verification

The focused domain file contains 13 tests covering probability boundaries, typical inputs, missing/nonfinite/out-of-range input, normalization/clamping, missing/invalid/equal/insufficient calibration, calibration replacement, EMA, invalid input reset, freshness gaps, duplicate/order rejection, lifecycle resets, collector average/peak/span, empty and excluded samples, and player/round isolation.

Repository-wide source discovery reports 239 Flutter `test`/`testWidgets` declarations. This is a source count, not an execution result.

| Check | Status | Outcome |
| --- | --- | --- |
| Focused smile domain tests | BLOCKED | Authored but Flutter SDK cannot bootstrap |
| Full `flutter test` | BLOCKED | Proxy CONNECT 403 downloading the Flutter Dart SDK |
| `flutter analyze` | BLOCKED | Same SDK bootstrap restriction |
| Supplemental Dart formatting | PASS | 44 changed/new Dart files; final repeat has no changes |
| Dart syntax parser | PASS | Zero syntax errors across `lib` and `test` |
| `git diff --check` | PASS | No whitespace errors |
| Security/manifest checks | PASS | Existing checks passed |
| Python tooling tests | PASS | 3/3 executed successfully |
| Physical-device camera validation | NOT TESTED | No device was available |

## Known limitations

- No genuine neutral/natural-smile probability capture or persistence exists, so production personalized intensity is unavailable by design.
- Domain tests cannot be claimed passing until Flutter compilation and execution are available.
- The collector uses sample average and observation span. It does not claim a time-weighted average or continuous coverage.
- UI and database integration are deliberately reserved for a later increment.
