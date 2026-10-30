# Phase 4D compatibility and validation findings

Status: **in progress; not device-validated or release-ready**. Device procedures and result fields are in [the Phase 4C/4D checklist](phase-4c-lifecycle-and-4d-device-validation.md).

## Configuration and builds

- Local toolchain: Flutter 3.47.7 / Dart 3.13.5. Project Dart constraint: `>=3.7.0`. Android uses AGP 9.4.1, Gradle 9.8.0, Kotlin 2.2.20, Java 17, and Flutter defaults compile/target SDK 36, min SDK 24 and NDK 28.2.13676358. These defaults are SDK-version dependent. Flutter warns Kotlin 2.2.20 and the app/plugin Kotlin Gradle Plugin setup need future migration; do not upgrade without compatibility testing.
- `flutter build apk --debug --no-pub` succeeded with the local Android SDK and Java proxy/system trust-store configuration. Debug APK: `build/app/outputs/flutter-apk/app-debug.apk` (approximately 229 MiB, debug/unstripped; not a release-size estimate). An earlier offline Gradle attempt failed because dependencies including AGP 8.12.1 and Kotlin 2.2.0 were not cached; a proxy attempt without the system Java trust store failed certificate validation.
- `flutter build apk --release --no-pub` failed at the project guard: a real `-PadmobAppId` was not supplied. The build also requires real interstitial/rewarded Dart defines, four signing environment variables and obfuscation/split-debug-info; these later checks were not reached. No credentials or production IDs were invented.
- Android application ID is `com.example.muskaan_minigame`; iOS bundle ID is `com.example.muskaanMinigame`. Review and choose production identifiers before publishing, accounting for any existing store identity.
- iOS deployment target is 15.5 and Swift setting is 5.0; the installed face-detection podspec also specifies iOS 15.5. No checked-in Podfile was found. This Linux environment cannot run Xcode, CocoaPods resolution or an iOS simulator/release build. Verify the intended Flutter plugin integration on macOS and signing/team configuration. iOS `Info.plist` lacks `GADApplicationIdentifier`; ads are disabled on iOS in `AdConfig`, but integration and SDK startup behavior remain unverified on iOS.

## Permissions, privacy and UX

- The main Android manifest declares camera and removes microphone and legacy external-storage permissions; audio is disabled in `CameraController`. The **debug merged manifest** additionally contains Internet, network state, advertising ID/AdServices, wake lock, foreground service and a dynamic-receiver permission. Manifest-merger evidence attributes advertising permissions to Google Mobile Ads and wake lock/foreground service to transitive measurement/WorkManager dependencies. Review necessity, ad privacy configuration and the release merged manifest; do not remove blindly without validating SDK behavior.
- The iOS camera usage explanation is present. ML Kit's native face detector is used locally; app source inspection found no camera-frame upload/persistence or camera/face logging in the inspected paths. Derived smile thresholds are stored locally in shared preferences. This does not prove third-party SDKs cannot access data or establish their complete telemetry behavior; verify dependency disclosures, ad consent and release privacy documentation separately.
- The UI has camera-error feedback with retry, a denied-permission settings path, safe-area/layout handling, some semantic labels and reduced-motion handling. Touch fallback replaces tilt movement; it is not a camera-free gameplay fallback. Screen-size, rotation, screen-reader readability, loading/recovery transitions and camera permission behavior require real-device testing.

## Device validation and remaining risks

- Android Debug Bridge reported no attached devices. No physical-device lifecycle, CPU, memory, battery, frame latency or responsiveness results exist.
- Linux has no Xcode; no iOS build or physical-device validation was performed. Native startup/disposal races and native cleanup after cancellation failure remain unverified for Android and iOS.
- Capture exact device model, OS, steps, expected/actual result and pass/fail in the companion checklist. Do not mark Phase 4D complete until its device and release-build blockers are resolved.

## Repository verification

`dart format .`: 89 files, no changes. `flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 243 passed. `git diff --check`: passed. Results are local; no commit or push was made.

## Android production configuration and permission audit

The current debug build uses Google's sample app ID in the merged manifest and `AdConfig` selects Google's test interstitial and rewarded units in non-release builds. In release, the Gradle guard requires a non-sample Android app ID (`admobAppId`, format `ca-app-pub-<16 digits>~<10 digits>`), and the Dart defines `ADMOB_INTERSTITIAL_ID` and `ADMOB_REWARDED_ID` (each `ca-app-pub-<16 digits>/<10 digits>`, non-sample publisher). Validation checks syntax and rejects the sample publisher; it does not prove account ownership. IDs ship in the app and are not secrets, but production values should be supplied by the release environment rather than committed.

The release environment must also supply `MUSKAAN_STORE_FILE`, `MUSKAAN_STORE_PASSWORD`, `MUSKAAN_KEY_ALIAS`, and `MUSKAAN_KEY_PASSWORD`. Keep the keystore, passwords and obfuscation symbols in restricted storage; never commit them. Gradle property `admobAppId` can be supplied through `ORG_GRADLE_PROJECT_admobAppId`. With authorized values already configured in a secure environment, the build form is:

```sh
flutter build apk --release --no-pub --obfuscate \
  --split-debug-info="$MUSKAAN_PRIVATE_SYMBOL_DIRECTORY" \
  --dart-define="ADMOB_INTERSTITIAL_ID=$MUSKAAN_ADMOB_INTERSTITIAL_ID" \
  --dart-define="ADMOB_REWARDED_ID=$MUSKAAN_ADMOB_REWARDED_ID"
```

Do not check environment values or generated symbols into the repository. Release guards require all fields and a real keystore path. The current release attempt stopped at `Release requires a real AdMob app ID: -PadmobAppId=ca-app-pub-...~...`; no production ID was supplied and the four signing variables were not set. Later unit-ID, signing and obfuscation guard checks were therefore not independently exercised by this build. Acquire authorized IDs/signing configuration and run the signed, obfuscated release build before considering it verified.

The actual **debug merged manifest** and merger report were inspected. There is no current release merged manifest because the release guard blocks the task; inspect it after a properly configured release build. No permission was removed in this audit: SDK requirements or effects of removal were not established sufficiently to make that change safely.

| Debug merged permission | Contributing source and decision |
| --- | --- |
| `CAMERA` | App main manifest and CameraX; required for face gameplay. Retain. |
| `INTERNET` | App debug manifest and Google Mobile Ads; used by Flutter debug tooling and ads. Retain. |
| `ACCESS_NETWORK_STATE` | Google Play services ads API and measurement; SDK network awareness. Retain pending dependency review. |
| `com.google.android.gms.permission.AD_ID` | Ads API and ads identifier; advertising ID access. Retain pending product/privacy and SDK review; assess consent and store disclosures. |
| `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS` | Play services ads API; advertising/Privacy Sandbox features. Retain pending verified SDK configuration and privacy review, not assumed essential for every deployment. |
| `WAKE_LOCK` | Play services measurement and AndroidX WorkManager; SDK/background-work behavior. Retain pending proof it is unnecessary. |
| `FOREGROUND_SERVICE` | AndroidX WorkManager; foreground work support. Retain pending proof it is unnecessary. No `FOREGROUND_SERVICE_*` subtype permission appears in the inspected debug merged manifest. |
| `com.example.muskaan_minigame.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX Core, signature-protected receiver permission; retain for dependency compatibility. |

The main manifest's removal directives exclude `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, and `WRITE_EXTERNAL_STORAGE` from the debug merged manifest. The merger report also records `RECEIVE_BOOT_COMPLETED` as removed/rejected by dependency merge rules; it does not appear in the final debug merged manifest. Camera-related `uses-feature` entries are not permissions; review the merged `android.hardware.camera.any` requirement separately for intended device availability.

Release enables R8 minification and resource shrinking with Flutter/ML Kit/AdMob/CameraX keep rules and multiple `-dontwarn` directives. These are configured but **not verified by a successful release build**; broad keeps and warning suppression deserve size/compatibility review after production credentials are available. The `com.example` namespace and application ID require an explicit release identity decision; changing an existing published ID would create a different app. Kotlin/AGP migration warnings are future maintenance work, not justification for a blind toolchain upgrade.

Latest verification: `flutter build apk --debug --no-pub` passed (17.7 s); `flutter build apk --release --no-pub` failed at the missing app-ID guard (18.7 s); `flutter analyze --no-pub` found no issues; `flutter test --no-pub` passed 243 tests; `dart format .` checked 89 files with no changes; `git diff --check` passed. Android/iOS physical-device validation and iOS builds remain outstanding. Phase 4D remains open.
