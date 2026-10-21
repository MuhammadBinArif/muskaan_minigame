import 'package:flutter/foundation.dart';

/// Android test units published by Google. iOS remains disabled until configured.
class AdConfig {
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const productionInterstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );
  static const productionRewarded = String.fromEnvironment('ADMOB_REWARDED_ID');

  static ({String interstitial, String rewarded}) select({
    required bool release,
    required String productionInterstitial,
    required String productionRewarded,
  }) =>
      release
          ? (interstitial: productionInterstitial, rewarded: productionRewarded)
          : (interstitial: _testInterstitial, rewarded: _testRewarded);

  static final _selected = select(
    release: kReleaseMode,
    productionInterstitial: productionInterstitial,
    productionRewarded: productionRewarded,
  );

  static String get interstitialId => _selected.interstitial;
  static String get rewardedId => _selected.rewarded;

  static bool get enabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (!kReleaseMode ||
          (productionInterstitial.isNotEmpty &&
              productionRewarded.isNotEmpty &&
              productionInterstitial != _testInterstitial &&
              productionRewarded != _testRewarded));
}
