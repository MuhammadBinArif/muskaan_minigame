# Phase 4L implementation and verification report

> Ownership storage was subsequently migrated to schema version 3. See `phase-4l.1b-result-ownership-avatar.md` for the current result schema.

Date: 9 November 2026. Work is local and uncommitted. No push, commit, backend deployment, camera capture, or physical-device validation was performed.

**Implementation is present; Flutter compilation and regression verification are BLOCKED. Do not treat this as a validated release.** The environment has no usable Flutter/Dart SDK. Flutter 3.44.0 source was downloaded into scratch space, but SDK bootstrap is denied by the network proxy for `storage.googleapis.com` (CONNECT 403, curl exit 56). The user authorized access, but the running environment's host policy still denies the download. No available configuration tool can apply that host change.

Statuses distinguish source inspection and supplementary checks from executed Flutter tests. PASS below does not imply device or Flutter runtime verification.

## 1. Root cause of fixed 92% — PASS (source audit and correction)

`SmileSpotlightScreen` defaulted to `score = 92` and `warmth = 92`; its router constructed it without any tracking input. Animated count-up displayed these constructor constants. Smile Width and Eye Sparkle were also demonstration values. This was not a normalization or calibration result.

There was a second disconnected path: `GameStats._smileScore()` derived its value from points, combo, and accuracy, quickly clamping to 100. It never consumed an ML probability. The active `VisionServiceImpl` enabled contours but not classification, and `FaceTrackingObservation` did not carry `Face.smilingProbability`.

The demonstration measurement defaults and invented breakdown values were removed. New rounds retain the legacy `smileScore` field for storage/API compatibility but no longer derive it from collisions or present it as a measured probability. Historical values are preserved verbatim.

## 2. Previous identity architecture — PASS (audit)

Profile held an editable name and selected avatar inside widget state. It initialized names to `PlayerName` or `Arjun Khan`. Home hardcoded `Arjun`; Challenges showed fictional leaderboard players/scores. Gameplay's avatar repository was unconfigured and fell back to a ninja emoji. Avatar Studio was a noninteractive container, not an existing customization service. No persisted profile, account backend, stable player ID, or record ownership column existed.

The repository uses feature folders, Riverpod StateNotifier/providers, and a local Drift SQLite database. No Firebase or global leaderboard service was found. The checked-out gameplay used calibrated mouth opening to catch food, not a smile-probability trigger. A Touch-Only implementation was not present.

## 3. New identity architecture — PASS (source); runtime NOT TESTED

`PlayerProfile` is immutable and stores a random 128-bit player ID, display name, emoji avatar, creation/update times, and onboarding completion. The display name never serves as a primary key or credential.

`PlayerProfileRepository` owns persistence in the existing database. `PlayerProfileController` serializes updates, saves before publishing, and retains the previous state after a failed write. Riverpod exposes one authoritative profile. No new backend or second database was added. Existing results remain separate immutable records associated by player ID.

## 4. Name generation and editing — PASS (source); runtime NOT TESTED

`FriendlyPlayerNameGenerator` uses an allowlisted friendly adjective/noun vocabulary and four-digit suffix to reduce collisions. Names are labels, with no global uniqueness guarantee. Initial creation saves the generated identity once. First-launch setup displays that saved name and allows an edited name or “Keep generated name”; later launches restore the profile and go Home.

Profile's Edit Name action writes through the controller. Validation trims outer whitespace, rejects empty/whitespace-only names, control and directional override characters, and more than 30 grapheme clusters or 120 UTF-16 units. Accents, international scripts, spaces, and joined emoji are permitted. Validation and disk failures leave the last saved name intact and show feedback.

`characters` was already a transitive dependency; it is now declared directly because the app uses grapheme counting. Its locked version/hash is unchanged. No other application package was added.

## 5. Authoritative screens and systems — PASS (source); runtime NOT TESTED

- First-launch setup and profile editing use the profile controller.
- Home, first-time Home, gameplay, Smile Spotlight, Challenges, game-over, results, and the local leaderboard display authoritative identity.
- Profile avatar options and the newly functional Avatar Studio sheet save the same emoji used by gameplay and result/leaderboard identity widgets.
- Home/Profile statistics filter records by current player ID, excluding unknown historical ownership. Demo profile statistics and the demo leaderboard identities were removed.
- Result and leaderboard presentation resolves current name/avatar for the matching stable ID. Other players use their stored snapshots; unidentified history is labelled legacy/unknown rather than assigned to the new player.

There is no separate character-board implementation in this checkout; Profile's player hub, gameplay character, and Challenges/local leaderboard are the existing corresponding surfaces. Existing challenge progress/reward demonstrations have not been converted into a complete achievement/challenge engine. The profile now explicitly labels achievement tracking as forthcoming.

## 6. Persistence and migration — PASS (SQL smoke test/source); Drift runtime BLOCKED

Schema version increases from 1 to 2. Versioned custom Drift SQL adds `player_profile` (one local profile slot) and `session_details` (ownership, snapshots, sample count, raw probability average/peak). The generated version-1 game table remains unchanged, avoiding rewriting legacy rows or generated schema code.

New score rows and their metadata are saved in one transaction. Retry IDs remain stable. Legacy rows have no metadata and therefore no assigned player or measured smile statistic. Profile creation checks storage inside a transaction. Corrupt saved profile data is preserved and surfaced through a safe unavailable state rather than silently overwritten. The setup screen offers an in-app retry and a confirmed replacement action; replacement creates a new stable identity only after the player accepts that the unreadable local profile will be replaced.

SQLite smoke execution of the exact extension-table statements passed and preserved a pre-existing record with its original score and legacy smile value. This is supplementary SQL validation, not proof that Drift's runtime migration passes. Automated Drift v1 migration and real file-reopen tests have been authored but could not run.

## 7. Smile probability and calibrated intensity — PASS (source); runtime NOT TESTED

The active ML Kit detector now enables classification. `Face.smilingProbability` is passed through the camera-independent observation boundary into `SmileMeasurementEngine`. Only valid finite values in [0,1] from a usable single face are accepted. Raw percentage is probability × 100, rounded for display. It is not an emotion, happiness, or health score.

The engine supports optional probability calibration with `(smoothedProbability - neutral) / (reference - neutral)`, clamped to [0,1]. References must be finite, ordered, within [0,1], and span at least 0.05. Invalid or absent references produce no personalized intensity.

**Personalized intensity collection/integration: BLOCKED by absent compatible calibration data/product flow.** Existing `CalibrationConfig` measures contour mouth openness, not neutral/natural-smile probabilities. Reusing those thresholds would manufacture a personalized measurement. That calibration and its catch thresholds are preserved. Current product UI explicitly identifies probability feedback and explains that personalized intensity is unavailable. No probability references have been invented.

## 8. Smoothing, validation, lifecycle — PASS (source); runtime NOT TESTED

The live display uses a constant-memory EMA with alpha 0.35. The unsmoothed raw probability remains separately available in each measurement and is used for round aggregation. No image, embedding, or per-frame observation history is stored.

Missing/nonfinite/out-of-range, unreliable, future, and older-than-500ms observations invalidate feedback. Duplicate and out-of-order timestamps are not new samples. Invalid future timestamps do not poison subsequent valid observations. A gap resets smoothing; tracking start/stop resets state. One cancellable expiry timer clears feedback even if camera callbacks cease. Camera interruption/error clears feedback. Timers and subscriptions are released on disposal. Gameplay distinguishes camera unavailable, face not detected, and measurement unavailable; Spotlight requires explicit camera start.

## 9. Results and leaderboard integration — PASS (source); runtime NOT TESTED

Round metrics are the frame-weighted arithmetic mean and peak of accepted raw smile probabilities, plus sample count. They are collected only while playing, with timestamp deduplication and freshness validation. Paused/absent observations do not create samples or award points. Zero samples means nullable/unavailable measurement, not 0% or 92% fabricated as a reading. Results label the average accurately. Raw frames are never saved.

The existing pending/open-mouth and collision scoring rules, object spawning, catch geometry, record retry behavior, and local/unverified result semantics remain intact. No claim of server verification was added.

Challenges links to a new leaderboard explicitly labelled “on this device.” It ranks each known player's best local record; legacy rows remain separately identifiable because their owners cannot be inferred. Profile edits change matching display identity without moving score ownership.

Touch-Only was added through a small input adapter: hold to open/catch and drag to move, using the same collision handler and target. Camera retry remains available alongside an in-place Touch fallback. Players can switch between Touch and Smile without leaving the route, disposing the round, or persisting a partial result. Touch entry avoids constructing camera/ML Kit providers; replay retains the selected input mode within the current app session. This behavior still needs widget/device verification.

Global leaderboard synchronization: BLOCKED — no backend exists. Adding one requires authenticated stable remote identity, authorization for profile/score writes, server validation/verification and replay protection, and privacy/data-retention design. Local IDs and scores are not authenticated or tamper-proof.

## 10. Files created, modified, removed

The exact working-tree file inventory is appended below. No files were removed. No generated database Dart file was edited. SDK/tooling downloads, logs, scripts and supplemental format/parser packages live under `/workspace/work`, outside the application.

## 11. New automated tests — PASS (authored); execution BLOCKED

16 new test cases are registered across five files:

- `test/profile/player_profile_test.dart`: identity creation/restore, Unicode validation, corruption preservation, reactive name/avatar changes, failed writes, independent repositories, round ownership and raw aggregate persistence.
- `test/profile/profile_migration_test.dart`: v1 history preservation and persisted name/avatar restoration across a file connection restart.
- `test/profile/identity_flow_test.dart`: first-launch acceptance/profile/Home flow, owned Touch-Only result, reactive result identity, and camera/ML providers that deliberately throw if constructed by Touch-Only.
- `test/smile/smile_measurement_test.dart`: 18/47/83 percent raw observations, normalization and invalid calibration, invalid/missing/stale/future observations, EMA response, duplicate/order filtering, gaps and resets.
- `test/smile/smile_pipeline_test.dart`: synthetic ML boundary frames through the real tracking controller, changing measurements, expiry, missing face and stop invalidation.

A memory-profile test adapter was added. Existing navigation and gameplay regression fixtures now supply a profile; obsolete assertions expecting hardcoded demo identities/92% were updated to the new behavior. No test was skipped to claim success.

## 12. Full test results

| Check | Status | Actual result |
| --- | --- | --- |
| `flutter test` (complete suite) | BLOCKED | Direct SDK bootstrap exits 56 because the proxy returns CONNECT 403. A prebuilt Flutter container also failed because the Docker daemon's layer store exhausted its capacity; zero Flutter tests executed |
| 16 newly authored Flutter cases | NOT TESTED | Same SDK blocker; no pass claim |
| Existing gameplay/camera/database/avatar/ads Flutter regressions | NOT TESTED | Same SDK blocker |
| Python tool suite | PASS | 3 tests executed successfully |
| SQLite extension-schema smoke | PASS | Statements execute; existing record retained |
| Physical camera/gameplay lifecycle and frame rate | NOT TESTED | No physical device tested |

## 13. Analyzer and formatting

| Check | Status | Actual result |
| --- | --- | --- |
| `flutter analyze` | BLOCKED | Same SDK bootstrap exit 56/CONNECT 403; type checking did not execute |
| Native `dart format` | BLOCKED | Dart executable not available |
| Supplemental local `dart_style` WASM port | PASS | 36 changed/new Dart files formatted; repeated check reports zero changes |
| Tree-sitter Dart syntax parsing | PASS | All current lib/test Dart sources parsed without syntax errors |
| `git diff --check` | PASS | No whitespace errors |
| Repository `tool/check_security.py` | PASS | Manifest policy, iOS plist/ATS, tracked signing/symbol files checks |

Formatting used `@wasm-fmt/dart_fmt` 0.4.0 in scratch, with Dart language version 3.7.0. This is a local third-party WASM port of `dart_style`, not the native SDK command and not an analyzer. Its source parser and the separate syntax parser cannot establish type correctness or runtime success.

Once the SDK host is enabled, run `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and the complete `flutter test` suite. Fix any findings before accepting this implementation. Native Android/iOS builds and physical-device tests remain necessary.

## 14. Performance and privacy — PASS (source inspection); profiling NOT TESTED

Smile processing and aggregation are constant-memory arithmetic at the existing camera rate; no new camera processing stream or FFI code was added. The expiry timer is owned by the tracking controller. High-frequency live feedback uses the existing tracking notifier/ValueListenable boundary. Profile updates occur on load/edit, and avatar dependencies select only the avatar. Database writes occur for profile edits and completed rounds, not camera frames. History metadata loads are batched rather than one query per record.

No camera-frame uploader, face-image persistence, facial embeddings, new permissions, analytics payload, or ad payload was added. Advertising/consent service logic was not modified. Only local profile fields and aggregate game metrics are persisted. Existing SQLite data remains locally editable and is not an authentication or global leaderboard security boundary. No physical memory/frame-time/thermal benchmarks or SDK network captures were performed.

## 15. Remaining limitations and acceptance status

| Requested requirement | Status | Scope/evidence |
| --- | --- | --- |
| 1. First-launch identity | PASS | Source implemented; Flutter runtime NOT TESTED |
| 2. Stable immutable player model | PASS | Separate random ID/name and one local profile |
| 3. Reactive single source | PASS | Riverpod profile used by relevant identity surfaces; runtime NOT TESTED |
| 4. Name editing/validation | PASS | Serialized durable update and Unicode validation; tests authored |
| 5. Avatar synchronization | PASS | Existing four options retained; Studio activated; tests authored |
| 6. Result/leaderboard ownership | PASS | Stable ID + snapshots; explicitly local; runtime NOT TESTED |
| 7. Persistence/migration | NOT TESTED | SQL smoke PASS; actual Drift migration/restart tests BLOCKED |
| 8. Fixed-92 root cause | PASS | Identified in source and removed |
| 9. Correct ML probability interpretation | PASS | Probability kept separate from emotion, catch threshold and points |
| 10. Dynamic/calibrated measurements | PASS | Raw/EMA implemented with safe uncalibrated fallback; personalized references unavailable |
| 11. Smoothing | PASS | EMA/reset/deduplication implemented; Flutter tests BLOCKED |
| 12. Live feedback states | NOT TESTED | Wired in source; rendering/device validation outstanding |
| 13. Catch/scoring preservation | NOT TESTED | Collision/spawn logic unchanged by diff; regression execution BLOCKED |
| 14. Historical/round metrics | PASS | Explicit raw mean/peak/count, nullable absent metric; runtime NOT TESTED |
| 15. Architecture | PASS | Feature/domain/repository/controller boundaries, same database, no backend |
| 16. Privacy | PASS | Source inspection only; physical traffic/storage validation NOT TESTED |
| 17. Performance | NOT TESTED | Source allocation/query inspection completed; no profiling |
| 18. Identity tests | NOT TESTED | Authored, not executed |
| 19. Measurement tests | NOT TESTED | Authored, not executed |
| 20. Integration tests | NOT TESTED | Authored synthetic/widget coverage; physical pipeline NOT TESTED |
| 21. Complete regressions/analyzer | BLOCKED | Flutter/Dart SDK host policy |

Additional limitations: one local player profile per database/device, with no account switching or cloud recovery; no verified remote score service; no compatible smile-reference capture flow; existing challenge/reward demo progress is outside this identity/measurement correction. The implementation must be compiled, analyzed and tested before declaring Phase 4L fully accepted.

## Working-tree file inventory

- `README.md`
- `docs/phase-4l-identity-smile.md`
- `lib/app/router/app_router.dart`
- `lib/core/domain/game_session.dart`
- `lib/core/providers/game_session_provider.dart`
- `lib/features/challenges/presentation/screens/challenges_screen.dart`
- `lib/features/game/data/game_database.dart`
- `lib/features/game/data/records_repository.dart`
- `lib/features/game/domain/play_mode.dart`
- `lib/features/game/presentation/flame/muskaan_flame_game.dart`
- `lib/features/game/presentation/screen/game_over_screen.dart`
- `lib/features/game/presentation/screen/gameplay_screen.dart`
- `lib/features/home/presentation/screens/home_first_time_screen.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/permissions/presentation/screens/camera_denied_screen.dart`
- `lib/features/profile/data/player_profile_repository.dart`
- `lib/features/profile/domain/player_name_generator.dart`
- `lib/features/profile/domain/player_profile.dart`
- `lib/features/profile/domain/profile_avatar.dart`
- `lib/features/profile/presentation/screens/local_leaderboard_screen.dart`
- `lib/features/profile/presentation/screens/player_setup_screen.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/widgets/player_identity.dart`
- `lib/features/results/presentation/screens/results_screen.dart`
- `lib/features/smile/domain/smile_measurement.dart`
- `lib/features/smile/presentation/screens/smile_spotlight_screen.dart`
- `lib/features/splash/presentation/screens/splash_screen.dart`
- `lib/features/tracking/data/vision_sevice_impl.dart`
- `lib/features/tracking/domain/face_tracking.dart`
- `lib/features/tracking/domain/mouth_tracking_provider.dart`
- `pubspec.lock`
- `pubspec.yaml`
- `test/app_navigation_test.dart`
- `test/game_flow_regression_test.dart`
- `test/profile/identity_flow_test.dart`
- `test/profile/player_profile_test.dart`
- `test/profile/profile_migration_test.dart`
- `test/smile/smile_measurement_test.dart`
- `test/smile/smile_pipeline_test.dart`
- `test/support/player_fixture.dart`
