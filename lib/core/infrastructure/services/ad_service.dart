import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kReleaseMode, ValueNotifier, ValueListenable;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

/// 환경에 따라 광고 ID를 반환한다.
///
/// .env에 키가 없으면 빈 문자열이 되고, load()가 조용히 돌아간다. 그러면
/// 광고가 아예 안 나오는데 오류도 안 뜬다. 배포 빌드에서 키 하나가 빠지면
/// 광고 수익이 0인 채로 아무도 모른다. 그래서 비면 기록을 남긴다.
String _resolveAdUnitId({
  required String androidProd,
  required String iosProd,
  required String androidTest,
  required String iosTest,
}) {
  final String key;
  if (kReleaseMode) {
    if (Platform.isAndroid) {
      key = androidProd;
    } else if (Platform.isIOS) {
      key = iosProd;
    } else {
      return '';
    }
  } else {
    if (Platform.isAndroid) {
      key = androidTest;
    } else if (Platform.isIOS) {
      key = iosTest;
    } else {
      return '';
    }
  }

  final id = dotenv.env[key] ?? '';
  if (id.isEmpty) {
    AppLogger.e('[Ads] 광고 ID가 비어 있다. .env에 $key 가 없다.');
  }
  return id;
}

/// 광고 서비스
class AdService {
  AdService._internal();
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  /// 광고 1회당 지급 패롯. 서버(functions/src/adReward.ts)의 AD_REWARD_PARROTS와 같다.
  static const int rewardCoins = 3;

  /// 광고 보상을 서버가 지급하는지.
  ///
  /// false(지금): 광고에 uid와 "verify-only"를 실어 보내 서버가 AdMob 서명만
  /// 확인하고 기록한다. 지급은 앱이 한다.
  /// true: "credit-v1"을 보내고 앱은 지급하지 않는다. 서버가 AdMob 확인을 받고
  /// 지급한다. AdMob 콘솔에 콜백 URL을 넣고 로그로 콜백이 오는 것을 본 뒤에만
  /// 켠다. 순서는 functions/src/adReward.ts 머리말에 있다.
  static const bool serverCreditsReward = false;

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
  ValueListenable<bool> get isRewardedAdReadyListenable =>
      _rewarded.readyNotifier;

  /// 보상형 광고를 불러오지 못했는지. 예전엔 실패해도 다시 부르지 않아 버튼이
  /// '광고 준비 중'으로 계속 돌았다(5차). 실패하면 버튼이 '다시 불러오기'가 된다.
  ValueListenable<bool> get isRewardedAdFailedListenable =>
      _rewarded.failedNotifier;
}

/// 전면 광고 (Interstitial)
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

/// 보상형 광고 (Rewarded)
class _RewardedAdController {
  /// 광고 상태 감지용: 초기 진입시 UI 버튼을 비활성한다.
  final ValueNotifier<bool> readyNotifier = ValueNotifier(false);

  /// 마지막 불러오기가 실패했는지(광고 단위 ID가 없을 때 포함).
  final ValueNotifier<bool> failedNotifier = ValueNotifier(false);

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
    if (_isLoading || _ad != null) return;
    if (_adUnitId.isEmpty) {
      failedNotifier.value = true;
      return;
    }
    _isLoading = true;
    failedNotifier.value = false;

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
          failedNotifier.value = true;
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

    final ad = _ad!;
    _ad = null;
    // AdMob 서버 측 확인(SSV) 콜백에 누구의 광고인지 싣는다. 로그인하지 않았으면
    // 싣지 않는다(서버는 user_id 없는 콜백에 지급하지 않는다).
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final options = uid == null
        ? null
        : ServerSideVerificationOptions(
            userId: uid,
            customData:
                AdService.serverCreditsReward ? 'credit-v1' : 'verify-only',
          );
    Future<void> showAd() => ad.show(
          onUserEarnedReward: (ad, reward) {
            onRewarded(AdService.rewardCoins);
          },
        );
    if (options == null) {
      showAd();
      return;
    }
    ad.setServerSideOptions(options).catchError((Object error) {
      // 못 실어도 광고는 보여준다. 확인 기록만 빠진다.
      AppLogger.e('[Ads][Rewarded] SSV 옵션 설정 실패', error: error);
    }).whenComplete(showAd);
  }
}
