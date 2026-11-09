# Phase 4L.6A — Audio System

## Status and audit

The original application had no audio dependency or assets. Settings and Pause
contained independent visual toggles that did not control playback. Game events
originate in `GameSessionNotifier`; rewards are evaluated only after a verified
result has persisted.

The implementation now uses one Riverpod-owned `AudioService`, one music player,
and one effects player. Widgets and Flame components never construct players.
The phase remains incomplete until Flutter validation and physical-device audio
testing can run.

## Dependency and architecture

- `audioplayers: ^6.8.1` is declared in `pubspec.yaml`. Pub.dev reports it as
  the current release; its Dart 3.6+/Flutter 3.44+ constraints are compatible
  with the recovered Flutter 3.47.9 checkout.
- `PlayerAudioBackend` is the only production package adapter.
- `AudioBackend` and `AudioPreferences` are mockable test boundaries.
- `AudioService` owns settings, route music, lifecycle, effect priority,
  throttling, persistence scheduling, initialization, and disposal.
- `FileAudioPreferences` stores JSON in application support storage. Writes use
  a temporary file and rename; rapid slider changes are debounced.
- Master audio defaults off, so initial onboarding does not autoplay.

Dependency resolution is blocked because Flutter must download its matching Dart
SDK from `storage.googleapis.com`, while the enforced network policy does not
allow that host. The official `dl.google.com` path returned HTTP 404 for this
engine artifact. No unofficial SDK, TLS bypass, or untrusted binary was used.
`pubspec.lock` consequently does not yet contain `audioplayers`.

Exact administrator intervention: add `storage.googleapis.com` to this managed
environment's HTTPS destination allowlist and apply the policy to environment
`ccarenv_b64_Y2NhcmVudl8yNmEzOGQ5YmIxNjQ4MTkxOWU1NjQ1MTYxMWNjNWJlNg`.
Then start a fresh connection and allow Flutter to retrieve only:

`/flutter_infra_release/flutter/89c39edfdfae2949f6806e4a315c0c08522238b7/dart-sdk-linux-x64.zip`

The observed failure is an HTTP 403 response to the proxy CONNECT request,
before any TLS handshake with Google. Proxy variables and CA trust are present,
so the failure is a destination-policy denial rather than certificate failure.
The Flutter source checkout is clean at tag 3.47.9, commit
`c197ca5199e9ee5661e865596c9c07294dfab51c`, with engine
`89c39edfdfae2949f6806e4a315c0c08522238b7` and expected Dart revision
`416e33b0ffaef062a60ec966bb8c82ed2b83f128`.

Android verification has separate provisioning prerequisites. The environment
currently has OpenJDK runtime 21.0.13, but no `javac`, Android SDK, `adb`,
`sdkmanager`, system Gradle, project `gradlew`, or wrapper JAR. The last two are
ignored by the repository rather than tracked. An administrator or reusable
environment image must provision an official JDK with compiler support and an
official Android SDK compatible with Flutter 3.47.9. The existing Gradle wrapper
declares 9.8.0; its official distribution and Android repository hosts are
already reachable through the policy.

## Music and lifecycle

| Routes | Track |
|---|---|
| Home, onboarding, profile, settings, challenges | `menu.wav` |
| Game and games | `gameplay.wav` |
| Game over, Results, Share | `results.wav` |
| Pause | Paused |

The backend sets looping mode per track, fades over eight 18 ms steps, avoids
restarting an unchanged track, and coalesces rapid route or volume changes.
Backgrounding and explicit interruption pause music and stop effects.
Foregrounding resumes the selected track. Disposal flushes the latest preference
snapshot and closes both players.

Effects use one player. An 80 ms gate suppresses duplicates; a unique priority
queue is capped at six entries. Ending and reward cues outrank gameplay feedback
and UI taps. Muting clears queued effects. Playback and missing-asset errors are
contained and never affect game state or result persistence.

## Event mapping

| Authoritative event | Sound |
|---|---|
| Successful edible collision | `catchFood.wav` |
| Gold food collision | `bonus.wav` |
| Every third active combo catch | `combo.wav` |
| Edible object expires below play area | `miss.wav` |
| Tea collision | `hazard.wav` |
| Three countdown states | `countdown.wav` |
| Owned round starts | `start.wav` |
| Valid pause / resume | `pause.wav` / `resume.wav` |
| Round ends | `gameOver.wav` |
| New player-owned best after persistence | `best.wav` |
| Achievement persisted | `achievement.wav` |
| Daily challenge newly completed | `challenge.wav` |
| Level increases after XP persistence | `level.wav` |
| Cosmetic unlock persists | `cosmetic.wav` |
| Short non-gameplay pointer tap | `tap.wav` |

Reward detection runs in the post-persistence callback and compares only the
stable result owner's history, awards, and unlocks. UI feedback ignores pointer
movement over ten pixels, long presses, and gameplay/countdown routes, so
scrolling and game input do not create tap sounds.

## Settings

Settings and Pause observe the same provider. Settings includes master audio,
independent music and effects switches, and independent volume sliders. Master
mute overrides both categories without destroying their values. Changes affect
memory and playback immediately; the latest snapshot persists after a short
debounce and restores at initialization. Haptic preference remains separate.

## Assets and licenses

`tool/generate_audio.py` reproducibly generates nineteen mono, 16-bit, 22,050 Hz
WAV files: three music loops and sixteen effects. They contain only original
procedural sine tones. `assets/audio/LICENSE.md` dedicates them to CC0 1.0.
The music is a functional prototype whose artistic quality has not been approved
through device listening.

## Privacy and platform configuration

No microphone API, recording, upload, analytics, or cloud audio was introduced.
Android explicitly removes `RECORD_AUDIO`; iOS has no microphone usage string.
Native plugin manifest merging and runtime audio focus still require builds.

## Verification evidence — 10 November 2026

- Eight audio tests declared: seven service/domain tests and one authoritative
  game-event integration test.
- Repository total: 295 declared Dart tests.
- Focused/full Flutter tests: **BLOCKED**, zero executed; SDK bootstrap failed
  with curl exit 56 / proxy HTTP 403.
- Analyzer and official Dart formatter: **BLOCKED** by the same bootstrap.
- Supplemental formatter: 78 Dart files, zero changes on the final pass.
- Supplemental syntax parser: zero syntax errors.
- Source security/manifest check: **PASS**; security tool tests: three passed.
- `git diff --check`: **PASS**.
- Android build, iOS build, interruption on hardware, loop quality, volume
  balance, and physical playback: **NOT TESTED**.

Fresh readiness command outcomes:

| Command | Exit | Outcome |
|---|---:|---|
| `/workspace/flutter-sdk/bin/flutter --version` | 56 | SDK proxy denial |
| `/workspace/flutter-sdk/bin/dart --version` | 56 | SDK proxy denial |
| `/workspace/flutter-sdk/bin/flutter pub get` | 56 | SDK proxy denial before resolution |
| `/workspace/flutter-sdk/bin/flutter test test/audio` | 56 | Zero tests executed |
| `/workspace/flutter-sdk/bin/flutter test` | 56 | Zero tests executed |
| `/workspace/flutter-sdk/bin/flutter analyze` | 56 | Analyzer did not start |
| `/workspace/flutter-sdk/bin/dart format --output=none --set-exit-if-changed lib test` | 56 | Official formatter did not start |
| `/workspace/flutter-sdk/bin/flutter build apk --debug` | 56 | Build did not start |
| `git diff --check` | 0 | Clean |
| `python tool/check_security.py` | 0 | Manifest/privacy policy passed |

After policy and toolchain provisioning, rerun the table in order, followed by
`flutter doctor -v`, dependency inspection, the three security-tool unit tests,
and an Android device pass. Regenerate `pubspec.lock` only through the verified
Flutter 3.47.9/Dart toolchain; do not edit it manually.

## Remaining limitations

The dependency must be resolved with the matching authorized Flutter SDK. Type
analysis, Dart tests, plugin-native permission inspection, platform builds, and
physical listening remain mandatory. Generated tracks need listening review for
loop boundaries and product quality. Native phone-call/headphone interruption is
not established by simulated lifecycle tests. Phase 4L.6A cannot be marked
complete until those checks pass.

All changes remain local and uncommitted. No recovered file was reset, cleaned,
stashed, discarded, or committed.
