import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Use the SDK codecs to exercise the real Dart/native callback boundary.
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';
import 'package:muskaan_minigame/features/ads/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final ads = instanceManager.channel;
  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );
  late AdService service;
  late List<int> interstitials;
  late List<int> rewarded;
  late List<int> disposed;
  late bool consent;

  Future<void> event(
    int id,
    String name, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final done = Completer<void>();
    await messenger.handlePlatformMessage(
      ads.name,
      ads.codec.encodeMethodCall(
        MethodCall('onAdEvent', {'adId': id, 'eventName': name, ...extra}),
      ),
      (_) => done.complete(),
    );
    await done.future;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    interstitials = [];
    rewarded = [];
    disposed = [];
    consent = true;
    service = AdService();
    messenger.setMockMethodCallHandler(ump, (call) async {
      if (call.method == 'ConsentInformation#canRequestAds') return consent;
      if (call.method ==
          'ConsentInformation#getPrivacyOptionsRequirementStatus') {
        return 1;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(ads, (call) async {
      if (call.method == 'MobileAds#initialize') {
        return InitializationStatus({});
      }
      if (call.method == 'loadInterstitialAd') {
        interstitials.add(call.arguments['adId'] as int);
      }
      if (call.method == 'loadRewardedAd') {
        rewarded.add(call.arguments['adId'] as int);
      }
      if (call.method == 'disposeAd') {
        disposed.add(call.arguments['adId'] as int);
      }
      return null;
    });
  });

  tearDown(() async {
    service.dispose();
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(ump, null);
    messenger.setMockMethodCallHandler(ads, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('consent denial prevents all SDK ad loads', () async {
    consent = false;
    await service.initialize();
    expect(interstitials, isEmpty);
    expect(rewarded, isEmpty);
  });

  test(
    'privacy change discards loaded ads even when ads remain permitted',
    () async {
      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      final oldInterstitial = interstitials.single;
      final oldRewarded = rewarded.single;
      await event(oldInterstitial, 'onAdLoaded');
      await event(oldRewarded, 'onAdLoaded');
      expect(await service.showPrivacyOptions(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(disposed, containsAll([oldInterstitial, oldRewarded]));
      expect(interstitials, hasLength(2));
      expect(rewarded, hasLength(2));
    },
  );

  test('revoking consent disposes ads and prevents new loads', () async {
    await service.initialize();
    await Future<void>.delayed(Duration.zero);
    await event(interstitials.single, 'onAdLoaded');
    await event(rewarded.single, 'onAdLoaded');
    consent = false;
    expect(await service.showPrivacyOptions(), isTrue);
    expect(service.interstitialState, AdLoadState.idle);
    expect(service.rewardedState, AdLoadState.idle);
    expect(interstitials, hasLength(1));
    expect(rewarded, hasLength(1));
  });

  test(
    'only the earned callback grants one reward; dismissal grants none',
    () async {
      await service.initialize();
      await Future<void>.delayed(Duration.zero);
      var grants = 0;
      final id = rewarded.single;
      await event(id, 'onAdLoaded');
      expect(
        await service.showRewarded(onEarnedReward: () => grants++),
        isTrue,
      );
      expect(grants, 0);
      final payload = {'rewardItem': RewardItem(1, 'test')};
      await event(id, 'onRewardedAdUserEarnedReward', payload);
      await event(id, 'onRewardedAdUserEarnedReward', payload);
      expect(grants, 1);
      await event(id, 'onAdDismissedFullScreenContent');
      expect(grants, 1);
      await Future<void>.delayed(Duration.zero);
      final next = rewarded.last;
      await event(next, 'onAdLoaded');
      await service.showRewarded(onEarnedReward: () => grants++);
      await event(next, 'onAdDismissedFullScreenContent');
      expect(grants, 1);
    },
  );

  test('duplicate interstitial dismissal cannot navigate twice', () async {
    await service.initialize();
    await Future<void>.delayed(Duration.zero);
    final id = interstitials.single;
    await event(id, 'onAdLoaded');
    var navigations = 0;
    for (var i = 0; i < 3; i++) {
      await service.replay(continueToCountdown: () => navigations++);
    }
    expect(navigations, 2);
    // Capture the SDK callback to simulate duplicate delivery after disposal.
    final ad = instanceManager.adFor(id) as InterstitialAd;
    final dismissed =
        ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!;
    dismissed(ad);
    dismissed(ad);
    expect(navigations, 3);
  });
}
