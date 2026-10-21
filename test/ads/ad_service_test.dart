import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/ads/ad_config.dart';
import 'package:muskaan_minigame/features/ads/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'replay ads start on the third replay and respect a three minute gap',
    () {
      final policy = ReplayAdPolicy();
      final start = DateTime(2026);
      expect(policy.shouldShow(start), isFalse);
      expect(policy.shouldShow(start), isFalse);
      expect(policy.shouldShow(start), isTrue);
      policy.markedShown(start);
      expect(policy.shouldShow(start), isFalse);
      expect(policy.shouldShow(start), isFalse);
      expect(policy.shouldShow(start.add(const Duration(minutes: 2))), isFalse);
      expect(policy.shouldShow(start.add(const Duration(minutes: 4))), isFalse);
      expect(policy.shouldShow(start.add(const Duration(minutes: 4))), isFalse);
      expect(policy.shouldShow(start.add(const Duration(minutes: 4))), isTrue);
    },
  );

  test('development configuration uses official Android test units', () {
    expect(kReleaseMode, isFalse);
    expect(AdConfig.interstitialId, 'ca-app-pub-3940256099942544/1033173712');
    expect(AdConfig.rewardedId, 'ca-app-pub-3940256099942544/5224354917');
  });

  test('release selects only supplied production IDs', () {
    final selected = AdConfig.select(
      release: true,
      productionInterstitial: 'production-interstitial',
      productionRewarded: 'production-rewarded',
    );
    expect(selected.interstitial, 'production-interstitial');
    expect(selected.rewarded, 'production-rewarded');
    expect(
      AdConfig.select(
        release: false,
        productionInterstitial: 'production-interstitial',
        productionRewarded: 'production-rewarded',
      ).interstitial,
      AdConfig.interstitialId,
    );
  });

  test('repeated reward or dismissal callbacks run the action once', () {
    final action = OneShotAction();
    var count = 0;
    action.run(() => count++);
    action.run(() => count++);
    expect(count, 1);
  });

  test(
    'replay continues without an ad and disposal prevents navigation',
    () async {
      final service = AdService();
      var count = 0;
      await service.replay(continueToCountdown: () => count++);
      expect(count, 1);
      service.dispose();
      await service.replay(continueToCountdown: () => count++);
      expect(count, 1);
      expect(service.interstitialState, AdLoadState.disposed);
    },
  );
}
