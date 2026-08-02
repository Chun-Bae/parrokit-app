import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode, ValueNotifier, ValueListenable;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

String _resolveAdUnitId({
  required String androidProd,
  required String iosProd,
  required String androidTest,
  required String iosTest,
}) {
  if (kReleaseMode) {
    if (Platform.isAndroid) return dotenv.env[androidProd] ?? '';
    if (Platform.isIOS) return dotenv.env[iosProd] ?? '';
    return '';
  } else {
    if (Platform.isAndroid) return dotenv.env[androidTest] ?? '';
    if (Platform.isIOS) return dotenv.env[iosTest] ?? '';
    return '';
  }
}

class AdService {
  AdService._internal();
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  /// 광고 1회당 지급 코인
  static const int rewardCoins = 3;

  final _InterstitialAdController _interstitial = _InterstitialAdController();
  final _RewardedAdController _rewarded = _RewardedAdController();

  /// 전면 광고를 미리 로드한다.
  void loadInterstitialAd() => _interstitial.load();

  /// 전면 광고를 보여준다.
  void showInterstitialAd() => _interstitial.show();

  /// 보상형 광고를 미리 로드한다.
  void loadRewardedAd() => _rewarded.load();

  /// 보상형 광고를 보여준다.
  void showRewardedAd({required void Function(int? coins) onRewarded}) =>
      _rewarded.show(onRewarded: onRewarded);

  /// 보상형 광고가 시청 가능한 상태인지 여부. 준비 중일 때 로딩 UI를 보여줄 때 구독한다.
  ValueListenable<bool> get isRewardedAdReadyListenable => _rewarded.readyNotifier;
}

// ─────────────────────────────────────────────────────────────────
// 전면 광고 (Interstitial)
// ─────────────────────────────────────────────────────────────────
class _InterstitialAdController {
  InterstitialAd? _ad;
  bool _isLoading = false;

  String get _adUnitId => _resolveAdUnitId(
        androidProd: 'ADMOB_INTERSTITIAL_ANDROID_PROD',
        iosProd: 'ADMOB_INTERSTITIAL_IOS_PROD',
        androidTest: 'ADMOB_INTERSTITIAL_ANDROID_TEST',
        iosTest: 'ADMOB_INTERSTITIAL_IOS_TEST',
      );

  void load() {
    if (_isLoading || _ad != null || _adUnitId.isEmpty) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              load();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _ad = null;
              AppLogger.e('[Ads][Interstitial] show failed', error: error);
              load();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          AppLogger.e('[Ads][Interstitial] load failed', error: error);
        },
      ),
    );
  }

  void show() {
    if (_ad == null) {
      load();
      return;
    }

    _ad!.show();
    _ad = null;
  }
}

// ─────────────────────────────────────────────────────────────────
// 보상형 광고 (Rewarded)
// ─────────────────────────────────────────────────────────────────
class _RewardedAdController {
  /// 광고 보기 버튼 비활성화용
  final ValueNotifier<bool> readyNotifier = ValueNotifier(false);

  RewardedAd? __ad;
  RewardedAd? get _ad => __ad;
  set _ad(RewardedAd? value) {
    __ad = value;
    readyNotifier.value = value != null;
  }

  bool _isLoading = false;

  String get _adUnitId => _resolveAdUnitId(
        androidProd: 'ADMOB_REWARDED_ANDROID_PROD',
        iosProd: 'ADMOB_REWARDED_IOS_PROD',
        androidTest: 'ADMOB_REWARDED_ANDROID_TEST',
        iosTest: 'ADMOB_REWARDED_IOS_TEST',
      );

  void load() {
    if (_isLoading || _ad != null || _adUnitId.isEmpty) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              load();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _ad = null;
              AppLogger.e('[Ads][Rewarded] show failed', error: error);
              load();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          AppLogger.e('[Ads][Rewarded] load failed', error: error);
        },
      ),
    );
  }

  void show({required void Function(int? coins) onRewarded}) {
    if (_ad == null) {
      load();
      onRewarded(null); // 준비 안 됨
      return;
    }

    _ad!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded(AdService.rewardCoins);
      },
    );
    _ad = null;
  }
}
