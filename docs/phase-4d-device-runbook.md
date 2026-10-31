# Phase 4D physical-device validation runbook

Status: **PREPARATION ONLY — all device cases NOT TESTED**. Phase 4C remains conditionally closed for the Dart-side milestone only; its ownership audit and caveats are in [the Phase 4C evidence](phase-4c-lifecycle-and-4d-device-validation.md). Release readiness and native resource cleanup are not established.

## Evidence categories

- **Source inspection:** configuration and control flow described below; not proof that native cleanup succeeds.
- **Automated tests:** 263 Flutter tests passed locally using controlled fakes where applicable; these are not physical-device evidence. The Phase 4C document names the specific lifecycle and fake-platform subscription tests.
- **Emulator/simulator:** NOT TESTED in this preparation. Simulator camera/ML Kit behavior may not represent a physical device.
- **Physical Android and iOS:** NOT TESTED. No device, performance, native teardown, permission-revocation or release-ad result is implied.
- **Historical build evidence:** earlier Android debug APK build passed, while release stopped at the missing AdMob app-ID guard. No Android build was run during this preparation. iOS builds have not been verified in the available Linux environment.

## Configuration audit and prerequisites

- Local Flutter 3.47.7 / Dart 3.13.5; project Dart constraint `>=3.7.0`. Android uses AGP 9.4.1, Gradle 9.8.0, Kotlin 2.2.20, Java 17 and Flutter-resolved compile/target SDK 36, min SDK 24 and NDK 28.2.13676358 for this SDK. Flutter warns about future Kotlin/AGP migration; verify on the actual build host rather than upgrading blindly.
- Locked plugins include `camera` 0.12.0+2, CameraX 0.7.2, AVFoundation 0.10.3+1, ML Kit face detection 0.14.0 and `google_mobile_ads` 9.1.0. The face-detection iOS podspec specifies iOS 15.5 and Swift 5; Xcode project target is also iOS 15.5. Actual Xcode, plugin, architecture and native dependency resolution compatibility remains NOT TESTED.
- Android application ID/namespace `com.example.muskaan_minigame` and iOS bundle ID `com.example.muskaanMinigame` are example identifiers. The owner must choose and register the intended store identities before release, without accidentally changing an existing published identity. Version is `1.0.0+1`; choose appropriate store build numbers.
- Android main manifest declares CAMERA, removes microphone and legacy storage permissions and marks specified camera features optional. The historical debug merge additionally contains a camera-any feature and advertising/measurement permissions; review device filtering and the actual release merged manifest. No permissions were removed during this preparation.
- iOS `NSCameraUsageDescription` exists, but describes mouth movement; review its wording for smile detection and optional camera-free play before release. There is no `GADApplicationIdentifier` in `Info.plist`. Ads are disabled by Dart `AdConfig.enabled` on iOS, but plugin integration and startup without that key are NOT TESTED. Do not enable iOS ads until the correct iOS app/unit IDs, SDK settings, consent and store disclosures are configured and tested.
- Gameplay lifecycle handles inactive/hidden/paused and resumed events; tracking invalidates generations, and camera operations serialize and normally drain frames before release. This is source/test evidence, not a native-device guarantee. Camera cancellation failure can leave native release unconfirmed.
- Store preparation requires accurate Google Play Data safety, ads and camera disclosures, app privacy policy, target audience/families declarations if applicable, and Apple App Privacy, privacy-manifest/SDK declarations and required-reason API review as applicable. Determine ATT applicability from actual SDK configuration and tracking behavior; no legal/compliance conclusion or completed store submission is implied. Check AdMob app readiness, account approval, `app-ads.txt` where applicable, consent and current platform policy with the account owner.

## Android: build and install

Prerequisites: Flutter dependencies resolved (`flutter pub get` when network access is available), Android SDK/build tools and licenses accepted (`flutter doctor -v`, `flutter doctor --android-licenses`), Java 17, compatible Gradle dependencies, an Android device at the resolved minimum SDK or newer, USB debugging authorization (or a correctly configured wireless device) and `adb`. Debug uses Google's sample app ID and test ad units; do not tap real ads while testing.

```sh
flutter devices
flutter build apk --debug --no-pub
adb -s "$ANDROID_SERIAL" install -r build/app/outputs/flutter-apk/app-debug.apk
```

Choose `ANDROID_SERIAL` locally from `adb devices`; debug may also be launched with `flutter run -d "$ANDROID_SERIAL" --debug --no-pub`. Installation over an existing package signed with another key can fail; do not uninstall user data without consent.

Release additionally requires an authorized real Android AdMob app ID in `ORG_GRADLE_PROJECT_admobAppId`, real interstitial and rewarded IDs in the two values below, and `MUSKAAN_STORE_FILE`, `MUSKAAN_STORE_PASSWORD`, `MUSKAAN_KEY_ALIAS`, `MUSKAAN_KEY_PASSWORD` configured privately, plus a restricted symbol directory. The guard validates format and rejects Google sample IDs; it cannot verify ownership. IDs are packaged in the app, while signing passwords and private keys must never be committed, pasted into chat or written to test evidence. Do not bypass the guard.

```sh
flutter build apk --release --no-pub --obfuscate \
  --split-debug-info="$MUSKAAN_PRIVATE_SYMBOL_DIRECTORY" \
  --dart-define="ADMOB_INTERSTITIAL_ID=$MUSKAAN_ADMOB_INTERSTITIAL_ID" \
  --dart-define="ADMOB_REWARDED_ID=$MUSKAAN_ADMOB_REWARDED_ID"
adb -s "$ANDROID_SERIAL" install -r build/app/outputs/flutter-apk/app-release.apk
```

For Play distribution use `flutter build appbundle --release --no-pub --obfuscate` with the same split-debug-info and Dart defines; an AAB is not directly installable with `adb`. Use an authorized internal test track or the proper bundletool workflow. Review R8/minification, resulting manifest, signing and Play Console declarations in the built artifact. Production ad testing requires registered test devices or approved test ads and appropriate consent; live ads must not be clicked for testing.

## iOS: build and install (macOS/Xcode required)

Prerequisites: a Mac with a Flutter-supported Xcode version, selected Xcode command-line tools and accepted license, iOS device support, Flutter and resolved plugins, and a trusted unlocked iPhone with Developer Mode where required. For signed builds use an authorized Apple team, a unique/registered bundle ID, appropriate development or distribution certificate and provisioning profile. Release/device or TestFlight distribution needs the applicable paid account and signing/export configuration. Never share certificates, keys or profiles in chat.

This checkout has **no checked-in `ios/Podfile`** and its `Debug.xcconfig` and `Release.xcconfig` only include `Generated.xcconfig`; generated plugin metadata in this Linux workspace reports iOS Swift Package Manager disabled. Several dependencies have CocoaPods specifications. On macOS, establish the supported Flutter/CocoaPods or Swift Package Manager integration for all plugins, including camera, ML Kit and ads; resolve any missing Podfile/xcconfig integration as a real build blocker. Do not assume `pod install` works before a valid Podfile exists. If CocoaPods is selected, install a compatible CocoaPods, resolve the Podfile and run `pod install` from `ios/`; if Swift Package Manager is selected, confirm every plugin and native binary supports it. Neither route is verified here.

```sh
flutter doctor -v
flutter pub get
flutter devices
flutter build ios --simulator --debug --no-pub
flutter run -d "$IOS_DEVICE_ID" --debug --no-pub
flutter build ios --release --no-pub
```

The simulator build is optional compatibility evidence and does not replace device testing. The device run requires working signing and plugin resolution. The final command creates a release device build if signing is configured; install via Xcode Devices and Simulators or use an appropriately signed/exported archive/TestFlight flow. `flutter build ipa --release --no-pub` requires correct archive/export signing. Commands are instructions, **not passed results**. Determine iOS SDK startup behavior with ads disabled before assuming the missing app ID is harmless; adding iOS production ad support is a separate, explicitly configured task.

## How to record each case

Run separately on a lower-resource and a high-end Android device, and representative supported iPhones; cover the lowest supported and a current OS version where available. For each execution record platform, physical model/chipset/RAM, OS version, build identifier/flavor, tester/date, setup and exact steps, expected and observed result, pass/fail/blocked, redacted device logs and evidence path. Record camera indicator and resource observations where applicable. A **PASS** requires every listed expectation and no crash, stuck screen, unexpected catch, duplicate visible camera use or unintended round reset; **FAIL** means an observed expectation fails; **BLOCKED** means it could not be performed (including failures that cannot be safely induced), never a pass.

| ID | Setup and steps | Expected / pass criteria | Evidence to capture | Android result | iOS result |
| --- | --- | --- | --- | --- | --- |
| D1 Permission | Fresh install; start Smile, grant; repeat with deny, system-settings revoke, later regrant and explicit retry. | Permission prompt is understandable; denial offers Touch, no repeated unsolicited prompt; Smile recovers after grant. | OS permission state, prompt/recovery steps, redacted logs. | NOT TESTED | NOT TESTED |
| D2 Mode transitions | Begin Smile round; score, switch Touch, catch; switch back and smile before and after fresh neutral. Repeat. | Same round/time/score persist; Touch works without camera; no catch before rearming, one eligible catch after. | Screen recording with consent, scores/time, camera indicator and logs. | NOT TESTED | NOT TESTED |
| D3 Lifecycle | During startup and active Smile, pause/resume and background/foreground repeatedly; use the player resume action. | Safe pause, no stale catch, no duplicate visible camera use, no stuck loading; recovery preserves round. | Timestamped lifecycle steps, UI state, camera indicator, logs. | NOT TESTED | NOT TESTED |
| D4 Interruption | Receive a call and attempt camera contention with another app, then return. | No crash or stuck camera; clear recovery/Touch fallback; existing round not silently restarted. | Call/contention timing, OS indicator and redacted logs. | NOT TESTED | NOT TESTED |
| D5 Startup errors | Safely induce unavailable camera, initialization and stream-start failure if possible; retry or choose Touch. | Actionable error, no silent mode switch or infinite loading; explicit retry succeeds when resource is available. | Reproduction method and failure/retry logs; mark each uninducible case BLOCKED. | NOT TESTED | NOT TESTED |
| D6 Cleanup and stability | Exit while detection runs; interrupt startup/cancellation; repeat 20 sessions and inspect camera use. Attempt cancellation failure only if safely reproducible. | No post-exit UI update or persistent camera use; repeated sessions recover; errors are reported safely. | OS indicator, platform logs, number of cycles, memory trend; cannot infer native release from fake counts. | NOT TESTED | NOT TESTED |
| D7 Camera-free play | Deny/revoke camera, select Touch-Only; play in normal and dark conditions. | No camera permission request/use; movement and catches work; game remains playable. | Permission state, OS indicator, actions and observed scores. | NOT TESTED | NOT TESTED |
| D8 Gameplay | Catch eligible/ineligible objects, trigger game over, inspect results and replay in both available modes. | Only eligible collisions score once; no scoring after game over; results and replay function. | Score timeline, actions, result/replay screens and logs. | NOT TESTED | NOT TESTED |
| D9 Layout and accessibility | Test smallest/largest available screens, notches/safe areas, rotate, increase text size, use TalkBack/VoiceOver. | No inaccessible or clipped essential controls; supported rotation remains usable; labels/readability adequate. | Model, display/scaling/orientation, annotated screenshots and reader observations. | NOT TESTED | NOT TESTED |
| D10 Performance | Sustained Smile and Touch play plus repeated sessions under similar light and thermal conditions. | No reproducible severe lag, excessive heat or runaway memory; record quantitative measurements rather than inventing a threshold. | Tools, duration, workload, CPU, memory, energy/battery, frame latency/dropped frames and thermal state. | NOT TESTED | NOT TESTED |
| D11 Release and ads | Install properly signed release; verify configured ads/consent using approved test devices; review iOS disabled-ad behavior. | Launch and gameplay work; consent and ad behavior match platform configuration, no live-ad test clicks. | Build/signing identity (not secrets), test-device setup, consent state, logs and result. | NOT TESTED | NOT TESTED |

Do not store production signing secrets, raw camera frames or identifiable face data in evidence. Report any unperformed failure injection and device/OS gaps explicitly.
