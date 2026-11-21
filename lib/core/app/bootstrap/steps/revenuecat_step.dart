import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// RevenueCat을 초기화하고 로그인 상태를 동기화한다.
Future<void> initRevenueCat(UserProvider userProvider) async {
  try {
    AppLogger.i('[Bootstrap][RevenueCat] start');
    String? apiKey;
    if (kDebugMode) {
      apiKey = dotenv.env['REVENUECAT_TEST_API_KEY'];
    } else {
      apiKey = Platform.isAndroid
          ? dotenv.env['REVENUECAT_ANDROID_API_KEY']
          : dotenv.env['REVENUECAT_APPLE_API_KEY'];
    }

    if (apiKey != null && apiKey.isNotEmpty) {
      // 디버그 빌드에서는 SDK 로그를 debug까지 연다(5차 514).
      //
      // Paywall의 구매 복원·구매 흐름을 RevenueCatUI는 debug 레벨로만 적는다.
      // 기본(info)에서는 복원을 눌러도 로그 한 줄이 안 남아, 시뮬레이터에서
      // 눌린 건지 아닌지조차 알 수 없었다. 출시 빌드는 그대로 둔다.
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      await Purchases.configure(PurchasesConfiguration(apiKey));
      if (userProvider.isLoggedIn && userProvider.currentUser != null) {
        await Purchases.logIn(userProvider.currentUser!.id);
      }
      AppLogger.i('[Bootstrap][RevenueCat] success');
    } else {
      AppLogger.w('[Bootstrap][RevenueCat] api key missing');
    }
  } catch (e) {
    AppLogger.e('[Bootstrap][RevenueCat] failed', error: e);
  }
}
