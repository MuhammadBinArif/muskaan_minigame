# Phase 5: Android AdMob test integration

The app currently uses Google Mobile Ads `9.1.0`. Debug Android builds use Google's sample application ID in `android/app/build.gradle.kts` and official test interstitial and rewarded unit IDs in `lib/features/ads/ad_config.dart`. No real account ID or secret is stored in the repository. Ads are disabled on iOS and web until those platforms are configured and verified.

The sole `AdService` is provided by Riverpod. Startup requests UMP consent information and displays a required form before `canRequestAds` permits loading. If UMP or the ads SDK fails, gameplay still starts. The profile screen exposes **Advertising privacy choices** when UMP reports that the entry point is required. Ads carry no camera frames, face landmarks, avatar, score, or session record; requests use `AdRequest()` with no application-specific targeting data.

The results screen offers Play Again only after result saving completes. Every third replay may show a preloaded interstitial, with a minimum of three minutes between shown ads. Missing, expired, failed, or unavailable ads immediately continue to countdown. Ads never appear in the game or countdown. The rewarded ad is preloaded as a foundation but has no player-facing action: this game currently has no supported revive or extra-life flow. A future reward must first define a safe game rule and connect an explicit opt-in action to `showRewarded`; its callback fires only from the SDK earned-reward event and is guarded against duplicates. Do not grant points or lives merely when an ad closes.

## Production release work

1. Create the Android app and interstitial/rewarded units in AdMob. Supply the real Android app ID to Gradle as `-PadmobAppId=ca-app-pub-...~...`. Supply real unit IDs to Flutter as `--dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-.../...` and `--dart-define=ADMOB_REWARDED_ID=ca-app-pub-.../...`. The debug build always uses Google test IDs, regardless of these values. A release build without a real app ID fails; missing production unit IDs disable ad requests.
2. Configure UMP messages and privacy options in AdMob for applicable regions. Confirm the intended audience and age treatment before enabling live ads. This repository does not define those policy decisions. Validate consent states and privacy-option visibility on a physical Android device, including background/foreground behavior.
3. Publish a privacy policy describing Google Mobile Ads data collection and update Play Console Data safety and advertising declarations. Verify applicable legal requirements with the app owner; the SDK integration alone does not establish compliance.
   Review the final merged manifest as well: existing plugins add microphone and legacy storage permissions in addition to camera and Internet.
4. Replace the repository's existing debug signing configuration for release with proper release signing as a separate release task. Register test devices; test only with official sample units or configured test devices. Never click live ads to test them.

The app's Android SDK is inherited from Flutter's current `flutter.minSdkVersion`. Verify the final merged manifest and runtime on a supported physical Android device before release. iOS requires its own AdMob application ID, test and production units, and `GADApplicationIdentifier` in `Info.plist` before enabling ads there.
