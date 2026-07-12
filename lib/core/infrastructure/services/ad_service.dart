import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._internal();
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  // ─────────────────────────────────────────────────────────────────
  // 전면 광고 (Interstitial)
  // ─────────────────────────────────────────────────────────────────

  InterstitialAd? _ad;
  bool _isLoading = false;

  String get _interstitialAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) return dotenv.env['ADMOB_INTERSTITIAL_ANDROID_PROD'] ?? '';
      if (Platform.isIOS) return dotenv.env['ADMOB_INTERSTITIAL_IOS_PROD'] ?? '';
    }
    if (Platform.isAndroid) return dotenv.env['ADMOB_INTERSTITIAL_ANDROID_TEST'] ?? '';
    if (Platform.isIOS) return dotenv.env['ADMOB_INTERSTITIAL_IOS_TEST'] ?? '';
    return '';
  }

  void loadAd() {
    if (_isLoading || _ad != null || _interstitialAdUnitId.isEmpty) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _ad = null;
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _ad = null;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _ad = null;
          debugPrint('❌ 전면 광고 로드 실패: ${error.code} - ${error.message}');
        },
      ),
    );
  }

  void showAd() {
    if (_ad != null) {
      _ad!.show();
      _ad = null;
    } else {
      loadAd();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 보상형 광고 (Rewarded) — 시청 시 코인 지급
  // ─────────────────────────────────────────────────────────────────

  static const int rewardCoins = 3; // 광고 1회당 지급 코인

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  String get _rewardedAdUnitId {
    if (kReleaseMode) {
      if (Platform.isAndroid) return dotenv.env['ADMOB_REWARDED_ANDROID_PROD'] ?? '';
      if (Platform.isIOS) return dotenv.env['ADMOB_REWARDED_IOS_PROD'] ?? '';
      return '';
    }
    if (Platform.isAndroid) return dotenv.env['ADMOB_REWARDED_ANDROID_TEST'] ?? '';
    if (Platform.isIOS) return dotenv.env['ADMOB_REWARDED_IOS_TEST'] ?? '';
    return '';
  }

  /// 보상형 광고를 미리 로드합니다.
  void loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null || _rewardedAdUnitId.isEmpty)
      return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          _rewardedAd = null;
          debugPrint('❌ 보상형 광고 로드 실패: ${error.code} - ${error.message}');
        },
      ),
    );
  }

  /// 보상형 광고를 보여줍니다.
  ///
  /// [onRewarded]: 시청 완료 시 지급 코인 수로 호출됩니다.
  /// 광고가 준비되지 않았으면 [onRewarded](-1)로 알립니다.
  void showRewardedAd({required void Function(int coins) onRewarded}) {
    if (_rewardedAd == null) {
      loadRewardedAd();
      onRewarded(-1); // 준비 안 됨
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onRewarded(rewardCoins);
      },
    );
    _rewardedAd = null;
  }

  bool get isRewardedAdReady => _rewardedAd != null;
}
