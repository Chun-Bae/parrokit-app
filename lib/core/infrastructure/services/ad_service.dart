import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kReleaseMode, ValueNotifier, ValueListenable, VoidCallback;
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
  /// false: 광고에 uid와 "verify-only"를 실어 보내 서버가 AdMob 서명만
  /// 확인하고 기록한다. 지급은 앱이 한다.
  /// true(지금): "credit-v1"을 보내고 앱은 지급하지 않는다. 서버가 AdMob
  /// 확인을 받고 지급한다. 잔액은 사용자 문서 구독으로 따라온다.
  ///
  /// 켜기 전에 2단계("verify-only")로 콜백이 실제 기기에서 통과하는 것을
  /// 봤다(5차 568). 그 전에는 AdMob이 user_id를 인코딩 전 글자로 서명해
  /// 네이버 계정(uid가 `naver:<id>`)만 서명이 깨졌다. 자세한 것은
  /// functions/src/adReward.ts 머리말과 admob-ssv 스킬에 있다.
  ///
  /// 릴리스에서만 켠다. 디버그 빌드는 Google 샘플 광고 단위를 쓰는데 그쪽은
  /// 우리 콜백 URL이 꽂혀 있지 않아 SSV 콜백이 아예 안 온다 - 켜 두면
  /// 시뮬레이터에서 광고를 봐도 패롯이 영영 안 들어온다.
  static const bool serverCreditsReward = kReleaseMode;

  final _InterstitialAdController _interstitial = _InterstitialAdController();
  final _RewardedAdController _rewarded = _RewardedAdController();

  /// 전면 광고를 미리 로드한다.
  void loadInterstitialAd() => _interstitial.load();

  /// 전면 광고를 보여준다.
  /// 전면 광고를 보여 준다. [onClosed]는 광고가 닫히거나, 띄우지 못했거나,
  /// 준비된 광고가 없어 그냥 지나갈 때 불린다(5차 372).
  void showInterstitialAd({VoidCallback? onClosed}) =>
      _interstitial.show(onClosed: onClosed);

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

  /// [onClosed]는 광고가 닫힌 뒤(또는 띄우지 못했을 때) 한 번 불린다.
  ///
  /// 전에는 부르는 쪽이 show() 바로 다음 줄에서 영상을 다시 틀었다. 광고는
  /// 그제야 올라오니, 광고를 보는 내내 뒤에서 소리가 났다(5차 372).
  void show({VoidCallback? onClosed}) {
    final ad = _ad;
    if (ad == null) {
      load();
      onClosed?.call();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        onClosed?.call();
        load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        AppLogger.e('[Ads][Interstitial] show failed', error: error);
        onClosed?.call();
        load();
      },
    );
    ad.show();
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
