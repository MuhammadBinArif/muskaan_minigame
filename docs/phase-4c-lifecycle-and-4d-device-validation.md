# Phase 4C lifecycle evidence and Phase 4D device validation

## Exit status

The app-controlled normal lifecycle and the specific interruption/recovery paths listed below are covered by automated tests. This is sufficient for **conditional Phase 4C closure as a Dart-side milestone**, with native-device validation a mandatory Phase 4D dependency. It is not a production-verification or release-readiness claim. The test matrix does not exhaust every lifecycle ordering or prove native cleanup after failure. In particular, a cancellation error cannot be retried through the installed controller once it marks streaming false, and native release is unconfirmed. A release decision must account for this risk and the Phase 4D results.

## Automated evidence

As of the local verification run: `flutter analyze --no-pub` reported no issues and `flutter test --no-pub` passed **243 tests**. Tests use fake camera hardware/platform and detector boundaries; they do not prove hardware behavior.

- `real controller creates and cancels one platform stream subscription`: the production service and real controller create one fake-platform stream subscription and cancel it once; repeated start, stop and disposal do not add calls.
- `disposal waits for platform stream cancellation after subscription`: a completer holds the fake platform cancellation future. Before release the test asserts one subscription, one cancellation attempt, zero successful cancellations and zero platform-controller disposals. After release it asserts one successful cancellation, zero fake-platform active subscriptions and one controller disposal.
- `stream startup failure creates no platform subscription` and `disposal during initialization creates no platform subscription`: zero subscriptions and cancellations in those tested paths. Startup failure here is synchronous, not delayed native failure.
- `failed platform cancellation is surfaced and cannot be retried by controller`: a failed cancellation is reported, the controller reports not streaming, and disposal calls the platform controller once without a second cancellation attempt. Native stream release is **not** observed.
- `async frame backpressure drops overlapping frames and disposal drains work` and `disposal drains active detection and rejects its late result`: serialized processing, draining, and rejection at their respective test boundaries.
- `production smile pipeline rearms after camera restart`: production camera service, vision service, tracking and smile trigger produce pending-catch entries **1 → 1 → 2 → 2** across player-driven restart using fake hardware/detector; a retained A callback is rejected.
- `pause drains an active camera frame before player resumes`, `leaving gameplay drains in-flight camera frame and ignores late lifecycle resume`, `interrupted restart candidate is released before player recovery`, and `gameplay callbacks cancel platform stream and pending restart cannot resubscribe`: the named screen-level interruption, drain and recovery scenarios. The latter observes one fake-platform subscription, one successful cancellation, maximum one active and zero active after disposal.
- `old camera callback cannot replace restarted tracking observation`: a deliberately non-draining camera fake tests the tracking generation guard, not overlapping production sessions. `permission denial followed by grant starts and releases one session` and `failed initialization releases candidate and retry creates a fresh session` test service-level retry; they do not prove OS permission-revocation recovery.

## Plugin inspection — not physical-device evidence

Installed versions: `camera` 0.12.0+2, `camera_platform_interface` 2.15.0, Android `camera_android_camerax` 0.7.2 and iOS `camera_avfoundation` 0.10.3+1. `CameraController.startImageStream` subscribes to `CameraPlatform.onStreamedFrameAvailable`; stopping cancels that Dart subscription. The controller does not expose native startup completion as an awaitable future.

Android CameraX starts asynchronous image-analysis binding/analyzer setup from stream listening; cancellation clears the analyzer, and camera disposal unbinds use cases and clears the analyzer. iOS AVFoundation starts the host image stream asynchronously, then attaches its image-data listener; cancellation requests host stop and listener cancellation, while camera disposal closes capture sessions and removes inputs and outputs. These are **source-inspection observations**, not proof that resources release successfully on a device or that asynchronous startup cannot race disposal. Native startup errors and cancellation failure behavior require device/platform investigation. In particular, controller streaming state changes before awaiting cancellation; a failed cancellation is surfaced but native release is not confirmed.

## Phase 4D physical-device matrix

Record the exact supported OS range from the final release configuration and dependency requirements before scheduling. The checked-in iOS deployment target is 15.5; Android uses Flutter's configured `minSdkVersion`, so confirm the resolved release value rather than assuming a number. Include at least a lowest-supported and current OS device on each platform, an Android low-resource device and a high-end device, and at least one representative iPhone per OS tier. Availability and actual supported versions must be recorded, not inferred from this plan.

| Case | Steps and expected result | Actual result / pass-fail |
| --- | --- | --- |
| Permission grant / denial / later grant | Deny on first request, retry or open settings, grant, return; camera recovers without app restart or duplicate sessions. Repeat permanent denial where supported. | Not run |
| Permission revocation | Revoke in system settings while backgrounded, return; error is safe and explicit; grant again and recover through player action. | Not run |
| Background during startup | Enter gameplay, background at camera initialization and streaming startup, foreground; no stale frames, stuck camera or duplicate session; recover via intended player flow. | Not run |
| Background during active streaming | Play, background and foreground repeatedly; camera releases/restarts, neutral rearming holds, controls and gameplay remain responsive. | Not run |
| Navigation during detection | Navigate away while face detection is active; verify no post-disposal updates and camera can be opened again. | Not run |
| Initialization / stream-start failure | Induce a reproducible permitted failure or use a supported diagnostic mechanism; verify visible error and retry without app restart. Record method; do not claim an uninduced failure was tested. | Not run |
| Delayed startup / cancellation | Where platform diagnostics can control or observe it, interrupt delayed startup and cancellation; verify native stream stops and no duplicate session remains. Include cancellation failure if reproducibly injectable. | Not run |
| Recovery and performance | Repeat play, pause/resume, and sustained streaming; record CPU, memory, battery/energy, frame latency, dropped frames and subjective gameplay responsiveness, with tool, duration, thermal state and workload. | Not run |

### Per-device result record

- Date / tester / build identifier and flavor:
- Device model, chipset, RAM, OS and version:
- Supported-version tier and physical device confirmation:
- Case and exact steps, including permissions and interruption timing:
- Expected result:
- Actual result, logs and evidence location:
- Subscription/camera indicators and resource observations:
- CPU / memory / battery or energy / frame latency / responsiveness, measurement tool and conditions:
- Pass / fail / blocked, issue link and follow-up:

No Android/iOS build, physical-device test or performance measurement was performed in this verification run.
