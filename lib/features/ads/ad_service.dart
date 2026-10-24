import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

enum AdLoadState { idle, loading, ready, showing, failed, disposed }

class OneShotAction {
  bool _used = false;

  void run(VoidCallback action) {
    if (_used) return;
    _used = true;
    action();
  }
}

/// Pure replay policy, kept separate from the SDK for deterministic tests.
class ReplayAdPolicy {
  ReplayAdPolicy({
    this.everyNthReplay = 3,
    this.minimumGap = const Duration(minutes: 3),
  });

  final int everyNthReplay;
  final Duration minimumGap;
  int _replays = 0;
  DateTime? _lastShown;

  bool shouldShow(DateTime now) {
    _replays++;
    return _replays % everyNthReplay == 0 &&
        (_lastShown == null || now.difference(_lastShown!) >= minimumGap);
  }

  void markedShown(DateTime now) => _lastShown = now;
}

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  ref.onDispose(service.dispose);
  return service;
});

/// Sole owner of SDK ads and consent. No game or camera data enters requests.
class AdService with WidgetsBindingObserver {
  AdService({ReplayAdPolicy? replayPolicy})
    : _replayPolicy = replayPolicy ?? ReplayAdPolicy();

  final ReplayAdPolicy _replayPolicy;
  AdLoadState interstitialState = AdLoadState.idle;
  AdLoadState rewardedState = AdLoadState.idle;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  DateTime? _interstitialLoadedAt;
  DateTime? _rewardedLoadedAt;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;
  bool _active = true;
  bool _disposed = false;
  bool _canRequestAds = false;
  bool _sdkReady = false;
  bool _initialized = false;
  bool _replayPending = false;
  bool _privacyOptionsPending = false;
  bool privacyOptionsRequired = false;
  int _interstitialGeneration = 0;
  int _rewardedGeneration = 0;

  Future<void> initialize() async {
    if (_initialized || _disposed || !AdConfig.enabled) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      // UMP must refresh before the first request. A cached decision may be
      // reused by UMP after a refresh error, but never inferred by the app.
      final updated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => updated.complete(),
        (error) => updated.complete(),
      );
      await updated.future;
      if (_disposed) return;
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {});
      if (_disposed) return;
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      privacyOptionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (!_canRequestAds || _disposed) return;
      await MobileAds.instance.initialize();
      if (_disposed) return;
      _sdkReady = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (_) {
      // Ads are optional; gameplay remains available on any SDK/UMP error.
      interstitialState = AdLoadState.failed;
      rewardedState = AdLoadState.failed;
    }
  }

  Future<bool> showPrivacyOptions() async {
    if (!privacyOptionsRequired || _disposed || _privacyOptionsPending) {
      return false;
    }
    _privacyOptionsPending = true;
    // Previously loaded ads may reflect a different consent decision even
    // when UMP still permits some advertising after the form is closed.
    _canRequestAds = false;
    _interstitialGeneration++;
    _rewardedGeneration++;
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
    interstitialState = AdLoadState.idle;
    rewardedState = AdLoadState.idle;
    try {
      FormError? formError;
      await ConsentForm.showPrivacyOptionsForm((error) => formError = error);
      if (_disposed || formError != null) return false;
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!_canRequestAds) return true;
      if (!_sdkReady) {
        await MobileAds.instance.initialize();
        if (_disposed) return false;
        _sdkReady = true;
        _loadInterstitial();
        _loadRewarded();
      } else {
        _loadInterstitial();
        _loadRewarded();
      }
      return true;
    } catch (_) {
      // Keep the game usable if UMP cannot reopen its privacy form.
      return false;
    } finally {
      _privacyOptionsPending = false;
    }
  }

  void _loadInterstitial() {
    if (!_canRequestAds ||
        _disposed ||
        interstitialState == AdLoadState.loading ||
        _interstitial != null) {
      return;
    }
    interstitialState = AdLoadState.loading;
    final generation = ++_interstitialGeneration;
    unawaited(
      InterstitialAd.load(
        adUnitId: AdConfig.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed ||
                generation != _interstitialGeneration ||
                !_canRequestAds) {
              ad.dispose();
              return;
            }
            _interstitial = ad;
            _interstitialLoadedAt = DateTime.now();
            interstitialState = AdLoadState.ready;
          },
          onAdFailedToLoad: (error) => _failInterstitialLoad(generation),
        ),
      ).catchError((Object error) => _failInterstitialLoad(generation)),
    );
  }

  void _failInterstitialLoad(int generation) {
    if (_disposed || generation != _interstitialGeneration) return;
    interstitialState = AdLoadState.failed;
    _interstitialRetry?.cancel();
    _interstitialRetry = Timer(const Duration(seconds: 30), _loadInterstitial);
  }

  void _loadRewarded() {
    if (!_canRequestAds ||
        _disposed ||
        rewardedState == AdLoadState.loading ||
        _rewarded != null) {
      return;
    }
    rewardedState = AdLoadState.loading;
    final generation = ++_rewardedGeneration;
    unawaited(
      RewardedAd.load(
        adUnitId: AdConfig.rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed ||
                generation != _rewardedGeneration ||
                !_canRequestAds) {
              ad.dispose();
              return;
            }
            _rewarded = ad;
            _rewardedLoadedAt = DateTime.now();
            rewardedState = AdLoadState.ready;
          },
          onAdFailedToLoad: (error) => _failRewardedLoad(generation),
        ),
      ).catchError((Object error) => _failRewardedLoad(generation)),
    );
  }

  void _failRewardedLoad(int generation) {
    if (_disposed || generation != _rewardedGeneration) return;
    rewardedState = AdLoadState.failed;
    _rewardedRetry?.cancel();
    _rewardedRetry = Timer(const Duration(seconds: 30), _loadRewarded);
  }

  /// Invoked only after a completed result is saved and the player taps replay.
  Future<void> replay({required VoidCallback continueToCountdown}) async {
    if (_replayPending || _disposed) return;
    _replayPending = true;
    final continuation = OneShotAction();
    void finish() {
      continuation.run(() {
        _replayPending = false;
        if (!_disposed && _active) continueToCountdown();
      });
    }

    final now = DateTime.now();
    if (!_active ||
        !_canRequestAds ||
        !_replayPolicy.shouldShow(now) ||
        interstitialState != AdLoadState.ready ||
        _interstitial == null) {
      finish();
      return;
    }
    final ad = _interstitial!;
    _interstitial = null;
    if (_interstitialLoadedAt == null ||
        now.difference(_interstitialLoadedAt!) >= const Duration(hours: 1)) {
      ad.dispose();
      interstitialState = AdLoadState.idle;
      _loadInterstitial();
      finish();
      return;
    }
    interstitialState = AdLoadState.showing;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) => _replayPolicy.markedShown(now),
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        interstitialState = AdLoadState.idle;
        _loadInterstitial();
        finish();
      },
      onAdFailedToShowFullScreenContent: (failed, error) {
        failed.dispose();
        interstitialState = AdLoadState.failed;
        _loadInterstitial();
        finish();
      },
    );
    try {
      await ad.show();
    } catch (_) {
      ad.dispose();
      interstitialState = AdLoadState.failed;
      _loadInterstitial();
      finish();
    }
  }

  /// Reserved for a future, explicitly defined game reward. The callback is
  /// called only by the SDK's earned-reward event, at most once per ad.
  Future<bool> showRewarded({required VoidCallback onEarnedReward}) async {
    if (!_active ||
        !_canRequestAds ||
        _disposed ||
        rewardedState != AdLoadState.ready ||
        _rewarded == null) {
      return false;
    }
    final ad = _rewarded!;
    _rewarded = null;
    if (_rewardedLoadedAt == null ||
        DateTime.now().difference(_rewardedLoadedAt!) >=
            const Duration(hours: 1)) {
      ad.dispose();
      rewardedState = AdLoadState.idle;
      _loadRewarded();
      return false;
    }
    rewardedState = AdLoadState.showing;
    final rewardGrant = OneShotAction();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        rewardedState = AdLoadState.idle;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (failed, error) {
        failed.dispose();
        rewardedState = AdLoadState.failed;
        _loadRewarded();
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (shown, reward) {
          if (_disposed || !_active) return;
          rewardGrant.run(onEarnedReward);
        },
      );
      return true;
    } catch (_) {
      ad.dispose();
      rewardedState = AdLoadState.failed;
      _loadRewarded();
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }

  void dispose() {
    _disposed = true;
    _interstitialGeneration++;
    _rewardedGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    interstitialState = AdLoadState.disposed;
    rewardedState = AdLoadState.disposed;
  }
}
