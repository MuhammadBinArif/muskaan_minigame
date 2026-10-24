# Phase 7 security review and hardening

Reviewed 24 October 2026. Scope: this Flutter repository, its available Git history, local tests, Android dependency resolution, and a debug APK. No third-party infrastructure or production users were tested. This is a source/configuration assessment with automated checks, **not a completed device penetration test or security certification**.

## A. Executive summary

Publication integration: upstream `main` subsequently added a network security configuration, custom native SDK ProGuard rules, additional ignore patterns, and moved code-generation packages to dev dependencies. These changes are preserved. Duplicate manifest/Gradle attributes introduced by the automatic merge were removed. The upstream configuration trusts user CAs only in debuggable builds; cleartext remains disabled. Its broad SDK keep/dontwarn rules remain an additional release-review item; statements below describing the initial audit refer to the pre-integration baseline.

**PARTIALLY HARDENED.** The changes close a release-validation bypass through aggregate Gradle tasks, require obfuscation and private symbol output for release, refresh cached advertising after privacy changes, validate local records, remove raw exception details from public error messages, and make Android backup/transport policy explicit. No Critical or High exploitable vulnerability was established by the performed checks. Missing production signing/AdMob configuration still blocks a release artifact; device testing and native-library/Apple dependency assessment remain incomplete.

The additional artwork request is implemented with the supplied Dart `FoodPainter`: shared golgappa icons and Flame's gold/pani foods now use it. Gameplay caches two vector pictures and disposes them on removal. Texture density is bounded, malformed canvas sizes are ignored, and movement/collision/scoring code is unchanged. The existing phone illustration is preserved.

Baseline before edits: Flutter 3.47.7, Dart 3.13.5, clean analysis, 184 passing tests; no existing test failure was observed. Android uses AGP 9.4.1, Gradle 9.8.0, Kotlin 2.2.20, JDK 17, min SDK 24 and target/compile SDK 36. Application ID remains `com.example.muskaan_minigame`, version `1.0.0+1`. No authentication, custom HTTP client/API, server leaderboard, payment flow, crash reporter, analytics integration, or existing CI workflow was found. An iOS target exists, but ads are intentionally disabled there and no iOS build was performed.

## B. Threat model and data inventory

Assets: camera access and transient frames, derived face/mouth state, local records, user consent choices, ad callbacks, source/release integrity, upload keys, and release symbols. Trust boundaries: OS permission/sandbox to native plugins; camera frames to ML Kit; native SDK callbacks to Dart; SQLite rows to domain/UI; release environment to Gradle; third-party advertising services to their SDK. The device owner can inspect or alter an offline game. There is no server that can enforce authoritative scores, rate limits, integrity verdicts, or financial rewards.

Realistic threats include an incorrectly configured release, package repackaging, runtime instrumentation, local DB edits/corruption, disclosure through errors/backups, reused consent-dependent ads, duplicated native callbacks, compromised dependencies, and network interception. No evidence of an app-controlled TLS bypass or camera upload endpoint was found. SDK traffic has not been captured, so this review does not assert that all SDK metadata stays local.

| Data | Location/use | Retention and sensitivity |
|---|---|---|
| Scores, catches, combos, duration, timestamps, derived smile score | Drift/SQLite `muskaan_minigame_game_records.sqlite` in application documents; ordinary game history | Until `clearAllSessions`, OS clear-storage, or uninstall. Not an authoritative leaderboard. Android backups/transfer now excluded; iOS document backup behavior remains a device-review item. |
| Profile name, settings, avatar | In-memory UI state and a bounded emoji avatar adapter; no file picker, imported image, avatar upload or persisted profile implementation | Screen/provider lifetime. Demo profile name/stats remain a product release issue from Phase 6. |
| Camera frames | Camera plugin stream → input-image converter → native ML Kit call | Transient processing, with frame backpressure and lifecycle cleanup. No application file writes or upload calls for frames found; no memory zeroization guarantee. |
| Facial positions/calibration | Controllers/providers and normalized game input | Session/provider lifetime and reset on stopping tracking. Not passed into `AdRequest`. |
| Consent state / ad identifiers | Google Mobile Ads and UMP managed native storage/traffic | SDK-defined; raw SDK stores and retention were not inspected on device. Owner must verify disclosures and messages. |
| Auth tokens / API caches | None found | Not applicable. No secret-storage package was introduced. |
| Diagnostics | Safe failure categories in UI; repository exceptions retain cause/stack internally | No app crash-reporting backend. Internal causes must not be exported unredacted by future telemetry. Native/SDK logcat requires device review. |
| Signing keys / symbols | Owner-provided external files/environment, not repository content | Owner-managed private retention and backup, correlated with release version/commit. Never ship symbols as app assets. |

## C. Findings register

Severity reflects this offline game's actual privileges. A hardening opportunity is not automatically a remotely exploitable vulnerability.

| ID / severity | Evidence and affected component | Impact and exploit preconditions | Fix, retest and residual risk |
|---|---|---|---|
| S01 Medium — confirmed release guard gap | `android/app/build.gradle.kts` previously examined only requested task-name strings for “release” | A developer invoking aggregate `assemble`/`build` could skip checks and generate misconfigured/unsigned release output. This did not confer a valid production signing key. | Validate the resolved app task graph; configure supplied signing independently of task spelling. Aggregate assemble dry run now fails before execution with the missing AdMob configuration message. Signed-release path remains untested without owner configuration. |
| S02 Medium — confirmed stale ad cache | `AdService.showPrivacyOptions` previously retained loaded ads if UMP still returned `canRequestAds=true` | A user changing advertising choices could receive a creative loaded under the previous decision. This is a cache-consistency finding, not a legal-compliance conclusion. | Pause requests, invalidate generations, dispose cached ads/cancel retries before opening choices; reload only after UMP allows it. Prevent overlapping privacy forms. SDK-boundary tests verify disposal/reload and revocation. Real UMP geography still requires device testing. |
| S03 Low — confirmed diagnostic disclosure path | Camera/face/tracking errors interpolated native exceptions into UI state; repository/save messages interpolated exceptions | A device/plugin/storage error could expose paths or internal error detail to the player. No actual credential disclosure was observed. | Stable retry messages; repository retains original cause/stack separately. Tests verify raw sentinel/native text is not exposed. Third-party logcat is outside this source-level check. |
| S04 Low — confirmed local validation gap | `GameSessionRecord`, database mapper, repository accepted out-of-range metrics; invalid stored state became `results`; stream errors escaped wrapping | A bug or an attacker already able to edit private storage could inject invalid values or disrupt history. No remote write path exists. | Reject invalid ranges/non-finite accuracy/date order and invalid enum state; wrap async stream errors. SQLite mutation tests verify safe failure and cleanup. Valid-looking score edits remain possible; corrupt database files are not silently erased or repaired. |
| S05 Low — implicit Android backup scope | Main manifest previously omitted backup policy | OS/cloud/device transfer could carry local records and SDK-managed state to another installation, subject to OS/account rules | Disable backup and full backup; add Android 12+ cloud/device-transfer exclusions including device-protected storage. Compiled debug manifest checked. OEM behavior and iOS backups remain unverified. |
| S06 Low — release hardening gap | No required Dart obfuscation/symbol-output options; signing ignores previously scoped mainly to Android directory | A normal release could be easier to inspect, or private release files elsewhere could be accidentally tracked | Require obfuscation/split symbols at release gate; private output wrapper and repository-wide signing/symbol ignores. R8/resource shrinking explicitly retained with Flutter's rules. Actual optimized artifact compatibility is blocked, not claimed verified. Obfuscation never protects embedded secrets. |
| S07 Low — duplicate iOS permission key | `ios/Runner/Info.plist` contained `NSCameraUsageDescription` twice | Platform parsing/build tooling could select inconsistent permission copy | Keep one explanatory description. XML/plist checks pass. iOS runtime and signing not tested on Linux. |
| S08 Informational — transport policy explicit | No custom endpoint/client, `badCertificateCallback`, permissive ATS exception, or source HTTP request found | SDK networking remains a trust boundary; Android API 28+ already defaults to denying cleartext | Explicit `usesCleartextTraffic=false`; no custom CA, trust-all hook, arbitrary SDK-domain pinning, or network exception introduced. Compiled policy checked; MITM/runtime TLS testing not performed. |
| S09 Informational — supply-chain coverage limits | Gitleaks and OSV results below; existing forced `permission_handler_android` version and native SDKs | A newly disclosed issue, compromised package, or embedded native library can remain undetected | Lockfile preserved; repeatable scans provided. No indiscriminate upgrades. Kotlin/plugin compatibility warnings, embedded C/C++ libraries and Apple pods still need review before release. |

## D. Security controls matrix

“Verified” here names the evidence scope; it does not imply device verification.

| Specification | Status | Evidence / decision |
|---|---|---|
| 1.1 Repository inspection | Implemented | Startup/router, Riverpod state, camera/ML Kit, avatar, Drift, ads, manifests, build files, dependencies, history, ignores reviewed. |
| 1.2 Threat model / finding severity | Implemented | Sections B/C; confirmed gaps distinguished from conditional risks. |
| 2.1 Release/debug/logging hardening | Implemented; artifact verification blocked | Graph guard; non-debuggable release, R8/shrink flags; private obfuscation wrapper. Debug banner already disabled. No app `print`/`debugPrint` found; SDK logs unverified. Demo profile data remains documented, not a security credential. |
| 2.2 Secrets / rotation / key restrictions | Already present and verified within scan scope; ignore policy extended | No matching secrets in available history/current snapshot. AdMob IDs are public configuration, not privileged credentials. No rotation warranted or claimed; production IDs/account restrictions still owner-managed. |
| 2.3 Android Play Integrity / iOS App Attest | Not implemented — backend-dependent | No protected server operation or token verifier. Client self-checks would not establish authority. Future server must verify and bind tokens to operations; Play/Apple account setup required. |
| 2.4 Root/jailbreak/emulator/debugger detection | Not implemented — deliberate risk decision | No financial/privileged operation to restrict. Avoid bypassable device bans, false positives, accessibility interference, and an extra fingerprinting SDK. Release debuggability is disabled separately. |
| 2.5 Selective screenshots | Not implemented — global blocking unjustified | No authentication/recovery/private-account screen. Ordinary game/results can be captured; a user can also capture their visible camera preview. Do not promise platform-wide screenshot prevention. |
| 3.1 HTTPS/cleartext/custom clients | Implemented / already present | Explicit Android deny; iOS ATS default retained; no app-controlled endpoint or certificate bypass found. SDK runtime traffic untested. |
| 3.2 Certificate pinning/rotation/expiry | Not applicable to current custom APIs | There are none. No unsupported pins placed on Google SDK domains. Future controlled endpoints require a rotation/failure plan. |
| 3.3 Auth expiry/refresh/storage/logout | Not applicable | No accounts, bearer tokens, JWT flow, or authenticated API. |
| 3.4 API authorization/rate limiting/schema/replay | Not applicable to existing APIs | No backend. A future server must validate scores/rewards and enforce limits; Flutter throttling is not server authorization. |
| 4.1 Data inventory / minimization | Implemented | Section B; no new data collection or provider added. |
| 4.2 Small-secret storage / avatar privacy / backups | No small secrets to store; backup policy implemented | No raw image storage/import path. Avatar is a bounded emoji; sandbox-backed ordinary scores do not justify a new encryption library. |
| 4.3 SQLite / migrations / corruption / encryption | Implemented / already present | Version 1 schema retained; parameterized Drift queries; validation on persistence/read; stream errors sanitized. No migration required. Malformed rows tested, full disk corruption/recovery untested. |
| 4.4 Logout/deletion/lifecycle | Logout not applicable; data clearing already present | `clearAllSessions` tested, scoped to game_records; no fictitious logout. No in-app clear-history button exists; Android OS clear-storage remains available. |
| 4.5 Crash/log privacy | Implemented for app messages; SDK logs unverified | Generic UI errors, internal repository cause/stack preserved. No unrelated crash/analytics service installed. |
| 5.1 Obfuscation / optimization | Implemented configuration; release verification blocked | `tool/build_release.sh` and Gradle gate. Flutter rules and upstream native SDK ProGuard rules preserved; review upstream broad keep/dontwarn rules against a real release build. |
| 5.2 Package / signature verification | Debug verified; production blocked | `aapt` metadata and `apksigner` verify debug key. Upload key and Play App Signing certificate are distinct; no client-only signature gate. |
| 5.3 Runtime monitoring | Not implemented — no backend/telemetry | No face measurements or identifying events added for monitoring. |
| 6.1 Camera/tracking | Already present and verified by source/unit tests | Permission on initialization; audio off; backpressure, generation cancellation, disposal and lifecycle tests. Raw frames only passed to local native detector in app code. Physical lifecycle, SDK metadata, memory and packet capture remain untested. |
| 6.2 Avatar/assets | Already present; supplied painter hardened | Emoji fallback bounds; no imported image/filesystem/upload surface. New texture loop bounds and non-finite-size check; cached gameplay pictures disposed. |
| 6.3 Scores/history | Validation implemented; local tampering accepted | No server leaderboard, financial prize, or tamper-proof claim. |
| 6.4 Ads/consent/rewards | Implemented / already present | Official SDK, UMP gating, refreshed caches, no frame/avatar targeting; actual Dart/native callback tests for consent, one-shot rewards and replay. No player-facing reward yet; server-side verification required if future rewards have external value. |
| 6.5 Dependencies/permissions | Assessed within scanner scope | 113 hosted Pub + 128 resolved Maven entries, no OSV matches. No extra permissions/packages added. Embedded native and Apple dependency scan incomplete. |
| 7 VAPT coverage | Partial | Repeatable results below; no unauthorized target or live attack. |
| 8 Automation | Implemented locally | Dependency API audit, manifest/tracked-file checks, parser tests, redacted Gitleaks commands. No CI existed; no external artifact upload or workflow enabled. |
| 9 Implementation rules | Applied | Small source/configuration boundaries; no new backend, fake integrity check, TLS bypass, custom crypto, production identifiers, secret, or anti-tamper SDK. |
| 10 Required checks | Completed where configuration permits | Section G. Signed obfuscated AAB deliberately not built without required production inputs. |

## E. Repeatable VAPT test register

Preconditions: a configured Flutter/Android/JDK environment for local checks; scanner network access for OSV; an authorized physical device and owner signing/ad configuration for runtime/release tests. PASS applies only to the stated objective.

| ID / platform | Objective and procedure | Expected result | Actual / status | Evidence / remediation and retest |
|---|---|---|---|---|
| V01 Dart/Android/iOS config | Run analyzer, formatter and `python3 tool/check_security.py` | Clean analysis, valid manifest/plist, no tracked signing/symbol files | PASS | Source checks; duplicate iOS key and public error details fixed. |
| V02 repository | Run Gitleaks 8.24.3 with `--redact` on all available Git refs and current tracked/non-ignored source snapshot | No detected credentials; never print values | PASS: 13 commits and current snapshot, no leaks | Official binary archive checksum verified. Scanner patterns cannot prove absence of all secrets or inspect inaccessible remote refs. |
| V03 Pub/Maven | Generate releaseRuntimeClasspath report; query OSV with names/versions using tool | No matching published advisory | PASS: 241 entries, no matches | `audit_dependencies.py`; scanner parser retested for selected versions/constraints/failure cases. Embedded native/iOS libraries NOT RUN. |
| V04 Android release artifact | With real config build obfuscated signed AAB; inspect classes/resources/symbol separation | Release non-debuggable, optimized, symbols private, SDKs intact | NOT RUN — inputs absent | No AAB generated, no claim of reverse-engineering resistance measured. |
| V05 Android logs/debug | Source review; inspect debug manifest; on device inspect release logcat | No sensitive UI/log content; release debug off | PASS for source/config; release logcat NOT RUN | Debug APK correctly debuggable, release flag false; raw UI errors removed. |
| V06 Android/iOS transport | Inspect compiled manifest and ATS; on device intercept only own test traffic | Cleartext denied and valid TLS required | PASS for configuration; runtime interception NOT RUN | Explicit Android policy, default ATS. No app HTTP client/bypass found. |
| V07 custom API pinning | Inventory owned endpoints; test pins/rotation if any | Only justified, maintainable pins | NOT APPLICABLE | No owned endpoint; no arbitrary advertising-domain pinning. |
| V08 storage | Inspect data types, sandbox DB path, backup rules; test clearAllSessions | No tokens/frames stored; scoped deletion | PASS for code/unit checks; backup transfer/device extraction NOT RUN | Database and repository tests; iOS backup remains open. |
| V09 authentication | Inventory account/token flows | Server auth and token safety where present | NOT APPLICABLE | No authentication. |
| V10 API penetration testing | Inventory backend targets before any active test | Only authorized owned endpoints tested | NOT APPLICABLE | No custom API; Google services not attacked. |
| V11 root/jailbreak/emulator/debugger | Inventory implemented detection; test policy if present | No fake success or accidental device bans | NOT APPLICABLE to detection tests | Detection deliberately not added. Runtime instrumentation still a residual risk. |
| V12 tamper/repackaging | Resolve release task graph with aggregate assemble dry run; later modify/re-sign test APK on device | Missing config blocked; signing/authenticity limitations documented | PASS for release guard; device repackaging NOT RUN | Aggregate dry run rejects absent production IDs before tasks execute. No installed signing trust claim. |
| V13 package/signature | `aapt dump badging` and `apksigner verify --print-certs` on debug APK; later inspect AAB/upload cert and Play-distributed cert | Expected ID/version/certificate | PASS debug; release NOT RUN | `com.example.muskaan_minigame`, `1.0.0`, code 1, debug certificate. |
| V14 camera/lifecycle | Existing denied/permanent/no-camera, late-init, frame-failure, pause/dispose tests; later device run | No crashes/leaked active camera or exposed native details | PASS automated; physical NOT RUN | Camera/tracking/controller regression suites. ADB cannot initialize its read-only home directory in this environment. |
| V15 ads abuse/consent | Simulate SDK method-channel callbacks, changed/revoked consent, duplicate earn/dismiss callbacks | No pre-consent requests, stale creatives, duplicate reward/navigation | PASS automated; live SDK/UMP network NOT RUN | `test/ads/ad_sdk_boundary_test.dart`; five real Dart/native-boundary cases. Sample-ID rejection/replay policy tests also pass. |
| V16 local DB integrity | Reject invalid write; mutate stored metrics/state via SQL; query/watch; clear records | Typed safe errors, no silent enum repair or duplicate saves | PASS | `test/records_repository_test.dart`; full on-disk corruption recovery NOT RUN. |
| V17 privacy leakage | Trace frames/avatar/records through app to ads; inspect public error strings; later packet/log capture | No app-specific camera/profile payload to ads | PASS source; SDK packet/log capture NOT RUN | Plain AdRequest, no uploader; SDK-managed identifiers/disclosures remain owner work. |
| V18 regressions/artwork | Run complete tests and build debug APK; render artwork and both gameplay foods | Gameplay preserved, deterministic supplied art, bounded texture and disposable cache | PASS on completed automated checks | Full results in G; physical rendering/frame-time/thermal behavior NOT RUN. |

## F. Changes and compatibility

- Build/manifests: `android/app/build.gradle.kts`, main manifest, new `res/xml/data_extraction_rules.xml`, iOS plist, `.gitignore`.
- Validation/errors: `lib/core/domain/game_session.dart`, session provider, database/repository, camera service, face-detection and mouth-tracking providers. Existing valid version-1 records remain compatible; invalid records now fail safely without deleting data. Repository error causes remain accessible internally.
- Ads: `ad_service.dart`, `ad_config.dart`; renewed caches/one privacy form at a time; reject every Google sample-publisher unit in release. A failed privacy form leaves ads disabled until a successful retry/reinitialization; gameplay remains available.
- Art: `food_illustrations.dart`, Flame food renderer; supplied crust presets and fillings, existing icon interface/phone illustration, bounded density, two cached vector pictures. No asset download or image-upload surface added.
- Tests: new food rendering and SDK-boundary tests; extended records, camera, face-detection, ad configuration and Flame tests.
- Tools: `check_security.py`, `audit_dependencies.py`, `test_security_tools.py`, `build_release.sh`. Python standard library only; network audit sends package coordinates, not source or secrets.
- Documentation: this report, release procedure and README cross-links. No production identifiers, keystores, symbols, generated APKs, or raw secret-scan artifacts are tracked.

## G. Verification and reproducible commands

Baseline: 184 tests and clean analyzer. The initial post-change run caught an old test expecting native error text plus test-only lint/internal-API warnings; those were fixed, including a regression assertion that raw native error text is hidden. No package cache was modified. Android builds retain pre-existing Kotlin 2.2.20 and ML Kit KGP migration warnings; these are compatibility work, not evidence of a discovered exploit.

Final executed results: `flutter pub get` passed; formatter checked 77 Dart files with zero changes; analyzer found no issues; **198 Flutter tests passed**; **3 dependency-audit parser tests passed**; shell syntax and source/merged-manifest policy checks passed. Debug APK build passed at `build/app/outputs/flutter-apk/app-debug.apk`; APK signature/metadata verified with Android tools. Gitleaks found no matching secrets and OSV returned no matches for 241 package/version entries. `git diff --check` passed. Aggregate release dry run failed with the expected configuration-blocker message. The dependency scanner initially rejected a Gradle `{prefer ...}` constraint; its parser was fixed to inspect the selected version and retested before the successful audit.

A release bundle is **NOT RUN** because production IDs/upload signing are absent. Its future path is `build/app/outputs/bundle/release/app-release.aab`, not an existing deliverable. ADB device enumeration failed with `Cannot mkdir '/home/agent/.android': Read-only file system`, including attempts to use available Android directory settings; no device test is claimed. The first attempt to fetch a security-tool archive used a nonexistent working directory; correcting the working directory allowed checksum verification and scanning. These were environment/tooling failures, not application vulnerabilities.

```sh
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
python3 tool/check_security.py
python3 tool/check_security.py --manifest build/app/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml
python3 -m unittest discover -s tool -p 'test_*.py'
bash -n tool/build_release.sh
gitleaks git . --redact --no-banner --log-opts=--all
# Scan a source-only snapshot of current tracked and non-ignored files too.
audit_snapshot=$(mktemp -d)
git ls-files --cached --others --exclude-standard -z | tar --null -T - -cf - | tar -xf - -C "$audit_snapshot"
gitleaks dir "$audit_snapshot" --redact --no-banner
./android/gradlew -p android :app:dependencies --configuration releaseRuntimeClasspath --console=plain > /tmp/muskaan-dependencies.txt
python3 tool/audit_dependencies.py --android-report /tmp/muskaan-dependencies.txt
# Negative test: must FAIL with missing production configuration, without building.
./android/gradlew -p android :app:assemble --dry-run
git diff --check
git status --short
git diff --stat
```

Use Gitleaks from its official release, pin its version, and verify its published checksum before execution. OSV service failure exits 2, advisory matches exit 1, and only a complete clean response exits 0. This scanner does not audit C/C++ vendored binaries or Apple pods. Do not interpret “no matches” as “no vulnerabilities.” Retain only redacted scanner summaries, and keep raw operational logs private.

## H. Outstanding requirements and release procedure

1. Owner confirms permanent package ID, target audience, privacy policy, Data safety, UMP messages/regions, real AdMob app/units and test devices. Resolve Phase 6 demo profile/statistics and final store assets before production. No account values were fabricated or rotated.
2. Install/configure a compatible Flutter/Android/JDK toolchain. Resolve native SDK/Kotlin migration warnings before a future toolchain upgrade. Review embedded SQLite/ML Kit binaries and the actual Apple pod resolution with appropriate scanners; macOS/Xcode required for iOS builds/runtime.
3. Set upload signing environment variables listed in Phase 6, `ORG_GRADLE_PROJECT_admobAppId`, `ADMOB_INTERSTITIAL_ID`, `ADMOB_REWARDED_ID`, and `MUSKAAN_SYMBOL_DIR` to a private per-version directory outside the repository. Update `pubspec.yaml` versionCode for each upload. Never enable shell tracing when supplying secrets.
4. Run the checks above, then `bash tool/build_release.sh`. This invokes `flutter build appbundle --release --obfuscate --split-debug-info="$MUSKAAN_SYMBOL_DIR"` with supplied production unit defines. No release build should be attempted until inputs are valid. Keep symbols privately with version/commit, preserve Flutter/R8 mapping files privately, and test symbolication before relying on crash diagnostics.
5. Inspect the generated release manifest, package/version and resources; use `python3 tool/check_security.py --manifest <merged-release-manifest> --release`. Verify AAB signing with `jarsigner -verify -verbose -certs <aab>`; inspect metadata with an official bundletool. For a distributed APK use `apksigner verify --print-certs <apk>` and compare to the Play App Signing certificate, which may differ from the upload key.
6. On an authorized physical device test fresh install, permissions, denied/no front camera, calibration, tracking loss, pause/background/disposal, records/replay, corrupt storage recovery, offline/weak network, UMP geographic states and privacy changes, ad failure/retry, TalkBack/text scale, and new artwork performance. Use only test ads or registered test devices. Capture release logcat/traffic under permission; verify Android backup/transfer and iOS document backup behavior.
7. If a future backend adds valuable rewards/leaderboards: implement server authorization, schema/rate/replay checks, AdMob server-side verification where appropriate, and Play Integrity/App Attest verification bound to the operation. Do not ship client-only checks as an authoritative security boundary.

## I. Residual risk

Client code, public ad IDs and locally stored scores can be inspected or altered on a controlled device. Obfuscation/R8 are cost-raising measures, not encryption or prevention of repackaging. Runtime hooks can bypass local validation and callbacks. Android signing authenticates installed updates under platform rules; a differently signed repackaged app can still be installed separately by a device owner. No root ban or client signature check would fix that trust problem.

No live TLS interception, device extraction/backup test, runtime hooking/repackaging exercise, optimized release smoke test, iOS build, or complete native vulnerability scan was performed. UMP/source checks do not establish legal compliance or AdMob approval. SDKs may collect metadata described in their disclosures; this app's lack of a camera uploader does not prove absence of all SDK network transmission.

## J. Recommendation

**READY FOR LIMITED INTERNAL TESTING WITH DOCUMENTED RISKS**, using the debug APK and official test ads. Production/Play release remains blocked by missing owner configuration and the unperformed release/device checks. This recommendation does not certify security or assert that a professional penetration test has been completed.

References: [OWASP MASVS](https://mas.owasp.org/MASVS/), [OWASP MASTG](https://mas.owasp.org/MASTG/), [Android network security](https://developer.android.com/privacy-and-security/security-config), [Android backup](https://developer.android.com/identity/data/autobackup), [Play Integrity](https://developer.android.com/google/play/integrity/overview), [Apple App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity), [Flutter obfuscation](https://docs.flutter.dev/deployment/obfuscate), [AdMob Flutter privacy](https://developers.google.com/admob/flutter/privacy), [rewarded ads](https://developers.google.com/admob/flutter/rewarded), [OSV API](https://google.github.io/osv.dev/api/).
