# Core flow and camera/calibration repairs

Base reviewed: `16ac52cfa8bd4d8638a6518c412dea8e8a69d4a4`.

## Implemented behavior

- Food enters above the screen and falls in normalized units per second. It no longer bounces at the top; missed food exits below the screen. Actual elapsed time drives movement. Decorative demo food is excluded from an active round.
- Pausing stops the round clock. Backgrounding pauses gameplay and releases the camera; resuming requires the player to resume explicitly. Start/resume waits for camera streaming, and camera errors pause the round with a retry action.
- Restart clears food, collisions, score, and bite state. Route exit stops timers without updating providers during widget disposal.
- A session key and start timestamp are allocated once per round. Game over caches one completed record shared by Results and persistence. Saving is single-flight, retries reuse the same key, and save errors remain visible. Play Again preserves an outstanding result until saving succeeds.
- History, best-score, and streaming queries include completed records consistently. Previously saved legacy game-over records remain visible without a schema migration.
- Game over navigates through the existing Game Over screen to Results.
- Camera initialization/disposal operations are serialized. Leaving during asynchronous initialization cancels publication and disposes a late controller. Leaving preparation/gameplay releases the camera, rather than merely stopping its image stream.
- Frame callbacks can return futures. The production service waits for asynchronous processing, drops overlapping frames, drains processing before disposal, and exposes processing failures. The detector is closed after camera work drains.
- Freshness is measured from frame reception rather than inference completion. Missing/invalid faces reset mouth transitions. Successful recovery clears stale errors/controllers.
- Calibration requires stable closed-mouth measurements, a distinct opening, and a confirmed close. It never succeeds just because timers elapsed. Face loss resets incomplete sampling; retry is available. Calibration is required before starting a game.
- Tracking coordinates use upright image dimensions and front-camera mirroring, and gameplay uses the tracked position rather than a fixed point. A visible marker shows the collision target. One sustained mouth opening consumes at most one food item; closing rearms it.
- NV21/BGRA input requires a packed single plane. Unsupported YUV layouts fail visibly instead of concatenating incompatible planes. Android frame rotation incorporates device orientation.
- iOS camera usage text explains on-device processing. No image persistence or upload was introduced.

## Automated verification

Run on Linux with Flutter **3.47.7** / Dart **3.13.5**:

| Check | Actual result |
| --- | --- |
| `flutter pub get` | Passed using the existing dependency constraints |
| `flutter analyze --no-pub` | Passed: no issues found |
| `flutter test --no-pub` | Passed: **156 tests** |
| `git diff --check` | Passed |
| `flutter build apk --debug --no-pub` | Blocked by Google Maven HTTP 503; no APK verified |

Relevant resolved packages were camera 0.12.1, camera_android_camerax 0.7.5+1, ML Kit face detection 0.14.0, Riverpod 2.6.1, Drift 2.31.0, and go_router 17.5.0. `pubspec.yaml` was not changed. The repository still ignores its application lockfile; another SDK may resolve different compatible package versions. This verification does not establish compatibility with every SDK allowed by the broad existing constraints.

Regression coverage includes production camera-service denial, missing camera, initialization failure/retry, cancellation during initialization, async backpressure, disposal draining, and processing errors; food traversal; pause/restart; bite consumption; tracked collision positions; stable result identity; failed-save retry; repeated database saves; synthetic calibration thresholds and coordinates; and widget flows for measured calibration and Game Over → Results → save retry.

Existing navigation tests were updated to require real measurements instead of expecting timer-only calibration success. Fake camera contract tests remain, supplemented by tests of the production service using an injected platform session.

## Android build blocker

The environment initially had no Flutter/Android SDK and only a Java runtime. Flutter, Android SDK/NDK, and Java 17/21 compilers were installed in scratch space. The build then reached Gradle dependency resolution but failed with:

```
Could not resolve androidx.resourceinspection:resourceinspection-annotation:1.0.1
Could not GET https://dl.google.com/dl/android/maven2/androidx/resourceinspection/resourceinspection-annotation/1.0.1/resourceinspection-annotation-1.0.1.pom
Received status code 503 from server: Service Unavailable
```

The same URL returned 503 on repeated direct requests through the configured proxy. Retry the debug build when that repository is available. No source-code build-success claim is made from this failed build.

Flutter also reported existing Kotlin 2.2.20 / legacy Kotlin Gradle Plugin migration warnings. Android Gradle/plugin versions were left unchanged. Treat their migration as a separate compatibility task.

## Required physical-device acceptance

NOT VERIFIED: no physical Android device was available.

1. Build/install the debug APK; grant camera access and confirm a continuously changing front-camera preview.
2. Deny access, retry, then test permanently denied access and return from Settings.
3. Leave during initialization, re-enter repeatedly, background/resume, and confirm the camera is released and recovers without duplicate sessions.
4. Complete closed → open → closed calibration. Verify no-face, unstable samples, unchanged mouth, and face loss cannot complete calibration. Test retry.
5. Check marker alignment while moving the face and rotating the device. Validate mirroring and any platform-specific preview crop behavior visually. Automated coordinate tests cannot establish camera alignment on hardware.
6. Catch food, confirm one catch per sustained opening, close/reopen to catch again, and test hazards, misses, pause timing, restart, and round end.
7. Verify Results matches the saved record, restart the app, and confirm history/best score remains available.
8. Test on a lower-powered Android phone: frame latency over the 200 ms freshness budget is rejected rather than treated as valid input. Tune only from device measurements.

## Scope and remaining limitations

The current 45-second duration, existing food types, and purple UI were preserved. This repair does not migrate the existing Flutter/Riverpod gameplay loop to Flame or implement rewards, cloud services, or Filmi Smile. A Flame migration remains a separate architectural task after device validation of the input pipeline. Mouth openness still uses the existing three-landmark approximation; synthetic tests do not prove detection accuracy for real users. iOS build/runtime behavior has not been verified.

Phase 3 cannot be declared accepted until an APK builds and the physical camera-to-gameplay checks above pass.
