# Phase 4C lifecycle evidence and Phase 4D device validation

## Exit status

The app-controlled normal lifecycle and the specific interruption/recovery paths listed below are covered by automated tests. This is sufficient for **conditional Phase 4C closure as a Dart-side milestone**, with native-device validation a mandatory Phase 4D dependency. It is not a production-verification or release-readiness claim. The test matrix does not exhaust every lifecycle ordering or prove native cleanup after failure. In particular, a cancellation error cannot be retried through the installed controller once it marks streaming false, and native release is unconfirmed. A release decision must account for this risk and the Phase 4D results.

## Automated evidence

As of the latest local verification run: `flutter analyze --no-pub` reported no issues and `flutter test --no-pub` passed **263 tests**. Tests use fake camera hardware/platform and detector boundaries; they do not prove hardware behavior.

- `real controller creates and cancels one platform stream subscription`: the production service and real controller create one fake-platform stream subscription and cancel it once; repeated start, stop and disposal do not add calls.
- `disposal waits for platform stream cancellation after subscription`: a completer holds the fake platform cancellation future. Before release the test asserts one subscription, one cancellation attempt, zero successful cancellations and zero platform-controller disposals. After release it asserts one successful cancellation, zero fake-platform active subscriptions and one controller disposal.
- `stream startup failure creates no platform subscription` and `disposal during initialization creates no platform subscription`: zero subscriptions and cancellations in those tested paths. Startup failure here is synchronous, not delayed native failure.
- `failed platform cancellation is surfaced and cannot be retried by controller`: a failed cancellation is reported, the controller reports not streaming, and disposal calls the platform controller once without a second cancellation attempt. Native stream release is **not** observed.
- `async frame backpressure drops overlapping frames and disposal drains work` and `disposal drains active detection and rejects its late result`: serialized processing, draining, and rejection at their respective test boundaries.
- `production smile pipeline rearms after camera restart`: production camera service, vision service, tracking and smile trigger produce pending-catch entries **1 → 1 → 2 → 2** across player-driven restart using fake hardware/detector; a retained A callback is rejected.
- `pause drains an active camera frame before player resumes`, `leaving gameplay drains in-flight camera frame and ignores late lifecycle resume`, `interrupted restart candidate is released before player recovery`, and `gameplay callbacks cancel platform stream and pending restart cannot resubscribe`: the named screen-level interruption, drain and recovery scenarios. The latter observes one fake-platform subscription, one successful cancellation, maximum one active and zero active after disposal.
- `old camera callback cannot replace restarted tracking observation`: a deliberately non-draining camera fake tests the tracking generation guard, not overlapping production sessions. `permission denial followed by grant starts and releases one session` and `failed initialization releases candidate and retry creates a fresh session` test service-level retry; they do not prove OS permission-revocation recovery.
- `pause and resume while smile to touch cleanup is held` and `pending touch catch clears when pause interrupts smile startup`: screen-level tests demonstrate recovery into a playable mode and a genuine eligible catch after interruption. The latter uses injected tracking state for the fresh smile observations.
- `three catches preserve one round across smile touch smile transitions`: three genuine collision scores across modes and neutral rearming; `old smile session callbacks cannot affect touch or replacement smile generation` covers a held late result and retained camera callbacks, with fresh tracking state injected for subsequent smile rearming.

## Lifecycle ownership audit

| Resource | Owner and cleanup boundary | Evidence and limits |
| --- | --- | --- |
| Camera session/controller | `CameraServiceImpl` owns each initialized `CameraSession`; its `PluginCameraSession` wraps the plugin `CameraController`. Initialization candidates are disposed if invalidated before ownership transfers. `dispose()` invalidates generations and serializes release; provider disposal calls `close()` asynchronously. | Session fakes verify candidate disposal and drain; real `CameraController` with a fake platform verifies the platform-facing Dart subscription. Fake session stops are not native subscription counts. |
| Image-stream subscription | The camera plugin's `CameraController` holds the subscription created from `CameraPlatform.onStreamedFrameAvailable`; `PluginCameraSession` delegates start/stop. The service controls when it starts and stops. | `real controller creates and cancels one platform stream subscription` and `disposal waits for platform stream cancellation after subscription` measure the fake-platform stream boundary. A cancellation failure is surfaced, but plugin state prevents retry through that controller; native release is unverified. |
| Vision service / ML Kit detector | `visionServiceProvider` owns `VisionServiceImpl`, which owns its detector. It reuses the detector across camera restarts; provider disposal starts asynchronous service disposal, which waits for active processing before closing the detector. The provider is not auto-disposed solely because gameplay exits. | `camera restart reuses provider-owned detector until provider disposal` observes one creation and one close at container disposal, not at camera disposal. This does not establish native detector teardown on devices. |
| Tracking generation and camera-state listener | `MouthTrackingController` owns the generation token and its camera-state subscription. `stopTracking()` invalidates the generation before requesting camera disposal; controller disposal invalidates it and initiates subscription cancellation and camera release asynchronously. | Generation checks after vision processing reject stale work. Provider/container disposal, rather than screen removal alone, owns controller destruction. |
| In-flight frame processing | `CameraServiceImpl` owns the single `_frameJob`, rejects overlapping frames, stops accepting frames before release and normally awaits the job before releasing the session. `VisionServiceImpl` separately tracks active detector calls before detector closure. | Automated controlled-future tests cover the normal drain and stale-result path. A failing stream cancellation takes an error path; do not infer native release or a completed camera drain from a stop call alone. |
| Pending Touch catch timer | Gameplay screen state owns `_touchCatchTimer`. A touch request creates the timer; collision consumption, mode switching, pause/game-over paths and screen disposal cancel it or clear the request. | Existing gameplay tests cover pending-request behavior. Exact timer creation/cancellation counts are not instrumented; no native resource claim follows. |
| Gameplay and provider disposal | Screen disposal invalidates screen generations, closes UI listeners, cancels its timers and starts tracking shutdown without awaiting it; service operations perform their own serialized cleanup. The container owns non-auto-dispose providers and starts their asynchronous cleanup on disposal. | Do not equate screen removal with completed provider/detector disposal. Tests observe fake resources at relevant boundaries; device teardown remains outstanding. |

## Old-generation observation disposition

| Observation ordering | Disposition |
| --- | --- |
| A result completes while Smile-to-Touch cleanup is pending | **PASS:** `old smile session callbacks cannot affect touch or replacement smile generation` holds an actual vision future, completes it after invalidation and asserts no request or score. |
| A face observation directly injected after cleanup in Touch mode | **NOT TESTED:** retained camera callbacks are tested after cleanup, but a separately injected face observation carrying A's invalidated token is not. |
| A face observation directly injected after replacement Smile session B starts | **NOT TESTED:** retained A camera callbacks are rejected and do not mutate B. In the production normal path the tracking callback captures A's generation and checks it after processing, while the camera service drains its in-flight frame before releasing A and starting B; this is an architectural explanation, not direct injection evidence or proof after native cleanup failures. |

No test-only production seam has been added to manufacture the latter two orderings. Native asynchronous behavior still requires device validation.

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

## Touch-only validation additions (not yet run)

On both Android and iOS, record the device model, OS version, build, exact steps, expected and actual outcomes, pass/fail and evidence for each case:

- Deny and revoke camera permission, then enter Touch-Only without a retry; the game should start without camera use.
- Play in complete darkness using Touch-Only; separately try Smile mode in bright and dim light and record detection failures without assuming uniform results across users.
- Tap rapidly, move while tapping, and catch multiple consecutive objects; record whether the 600 ms catch window feels responsive and whether only eligible collisions score.
- Switch modes during gameplay, including a camera interruption and denied permission; verify score, timer, object state and observable camera activity.
- Pause/resume while a catch is pending; verify it clears and the player can request another catch.

All items are pending; no physical-device results are claimed.

## Phase 4D execution checklists — all NOT RUN

Use physical devices at the lowest supported and a current OS version where available, including at least one lower-resource Android device and representative iPhones. Confirm the actual supported OS range and build identifiers before testing. For **each** row, record device model, OS version, app build/flavor, exact reproduction steps, expected and observed behavior, relevant redacted logs or evidence links, and PASS / FAIL / BLOCKED. Never record facial images or sensitive data in logs without explicit consent.

### Android physical devices

| Test | Steps and expected behavior | Evidence / result |
| --- | --- | --- |
| Permission grant, denial, revocation and regrant | Grant, deny, permanently deny if available, revoke in system settings and later grant; Touch remains playable without permission and Smile recovery follows explicit user action. | NOT RUN |
| Startup and failure | Start Smile; reproduce camera-in-use/unavailable and stream-start failure if feasible. Confirm feedback, Touch fallback and explicit retry; record how failure was induced. | NOT RUN |
| Pause/resume and background/foreground | Interrupt initialization and active Smile streaming; repeat pause/resume and background/foreground. Confirm no stuck loading, stale catch or duplicate camera activity. | NOT RUN |
| Calls and camera interruption | Receive an incoming call and exercise another camera-using app where supported; return and verify safe recovery. | NOT RUN |
| Switching and recovery | Repeatedly switch Smile → Touch → Smile while playing, including interrupted startup; confirm fresh neutral rearming and the same round, score and time. | NOT RUN |
| Cancellation and cleanup errors | Interrupt startup and streaming; induce cancellation/disposal failure only if safely reproducible. Check OS camera indicators and platform logs; report inability to inject failure as BLOCKED, not a pass. | NOT RUN |
| Repeated sessions and leaks | Enter and leave gameplay repeatedly, including during detection. Measure camera activity, memory, CPU, battery/energy and frame latency; look for resource growth and responsiveness problems. | NOT RUN |
| Layout and accessibility | Test small/large displays, safe areas, orientation behavior, font scaling, screen reader labels and accessible touch targets. | NOT RUN |
| Release and AdMob | Verify a correctly signed release build with real supplied configuration and consent handling; use approved test ads/test devices when testing, verify no sample IDs ship unintentionally. | NOT RUN |

### iOS physical devices

| Test | Steps and expected behavior | Evidence / result |
| --- | --- | --- |
| Permission grant, denial, revocation and regrant | Grant or deny camera access, revoke/regrant in Settings; confirm Touch works independently and Smile recovers only after explicit action. | NOT RUN |
| Startup and failure | Start Smile, exercise a reproducible camera-unavailable or stream-start failure where feasible, and verify a clear error, Touch fallback and explicit retry. | NOT RUN |
| Pause/resume and background/foreground | Interrupt camera initialization and active streaming using app switching/backgrounding; repeat and verify correct recovery without stale catches or duplicate streams. | NOT RUN |
| Calls and camera interruption | Receive an incoming call and test camera contention where supported; verify interruption handling and recovery without restarting the round. | NOT RUN |
| Switching and recovery | Repeated Smile → Touch → Smile transitions during active play and interrupted startup; verify round, score, timer and fresh-neutral rearming. | NOT RUN |
| Cancellation and cleanup errors | Interrupt startup/streaming and observe camera indicator and device logs; reproduce cancellation failure only where safely possible and record limitations. | NOT RUN |
| Repeated sessions and leaks | Repeat gameplay entry/exit during detection; measure camera activity, memory, CPU, energy, frame latency and responsiveness. | NOT RUN |
| Layout and accessibility | Test representative small/large iPhones, safe areas, rotation behavior, Dynamic Type, VoiceOver and touch targets. | NOT RUN |
| Release and AdMob | Verify signed release configuration, camera usage description, consent and AdMob settings; test ads using approved test configuration and confirm production identifiers before distribution. | NOT RUN |

### Result record for each case

- Device model / OS version / physical-device confirmation:
- App build, signing/flavor, date and tester:
- Reproduction steps and interruption timing:
- Expected behavior:
- Observed behavior:
- Redacted logs, camera indicators, measurements and evidence location:
- PASS / FAIL / BLOCKED, issue and follow-up:
