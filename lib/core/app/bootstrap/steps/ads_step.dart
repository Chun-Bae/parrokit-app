import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parrokit/core/infrastructure/services/ad_service.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

// 광고 SDK를 초기화하고 테스트 디바이스를 등록한다.
Future<void> initAds() async {
  try {
    AppLogger.i('[Bootstrap][Ads] start');
    await MobileAds.instance.initialize();

    final configuration = RequestConfiguration(
      testDeviceIds: [
        '49CD5924-A2F7-4DD9-9FD2-5545ACD55D6B',
        '9DBB0D7B-2CDF-440E-A886-134E853705BB',
        'B298412BB206519738CFD5AEFB066264',
      ],
    );

    await MobileAds.instance.updateRequestConfiguration(configuration);
    AdService().loadInterstitialAd();
    /// 보상형 광고는 더보기 페이지에 들어갈 때 로드 된다.
    AppLogger.i('[Bootstrap][Ads] success');
  } catch (e) {
    AppLogger.e('[Bootstrap][Ads] failed', error: e);
  }
}
