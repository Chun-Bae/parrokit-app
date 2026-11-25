import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:parrokit/core/app/config/firebase_options.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/word_cloud_store.dart';
import 'package:parrokit/core/content/sentence_cloud_store.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

// Firebase 앱 인스턴스를 초기화한다.
Future<void> initFirebase() async {
  try {
    AppLogger.i('[Bootstrap][Firebase] start');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
    await _activateAppCheck();
    // 로그인한 사용자의 내 문장은 Firestore에 보관한다.
    MySentenceStore.cloud = SentenceCloudStore();
    // 내 단어도 같은 방식. words 규칙이 배포되기 전에는 저장이 실패하고
    // MyWordStore가 이 기기에 남긴다.
    MyWordStore.cloud = FirestoreWordCloud();
    AppLogger.i('[Bootstrap][Firebase] success');
  } catch (e) {
    AppLogger.e('[Bootstrap][Firebase] failed', error: e);
  }
}

/// App Check을 켠다(5차, 사용자 요청).
///
/// 함수를 부를 때 "이 호출이 진짜 이 앱에서 왔는지"를 증명하는 토큰을 같이
/// 보낸다. 로그인만으로는 못 막는 것을 막는다 - 계정 하나만 있으면 앱 밖에서
/// 자막·예문·TTS를 부를 수 있고, 그 셋은 호출할 때마다 요금이 나간다.
///
/// **지금 서버는 이 토큰을 검사하지 않는다**(`functions/src/appCheck.ts`의
/// `ENFORCE_APP_CHECK`가 false). 앱이 먼저 토큰을 보내기 시작하고, Firebase
/// 콘솔의 App Check 모니터링에서 올바른 토큰을 달고 오는 비율이 충분히
/// 올라간 것을 보고 나서 서버를 true로 바꾼다. 순서를 바꾸면 그 순간 모든
/// 호출이 거절된다.
///
/// 첫 출시에 이걸 넣는 까닭: SDK 없는 버전을 먼저 내보내면 "그 버전이 퍼질
/// 때까지" 기다려야 켤 수 있다. 처음부터 들어 있으면 1일차에 전원이 들고
/// 있으므로 기다릴 것이 없다.
///
/// debug 빌드는 Debug provider를 쓴다. 시뮬레이터와 에뮬레이터에는 App
/// Attest·Play Integrity가 없어서 실기기가 아니면 토큰을 못 만든다. Debug
/// provider가 찍어 주는 토큰을 콘솔에 등록하면 개발 중에도 쓸 수 있다.
///
/// 실패해도 넘어간다. 서버가 아직 검사하지 않으므로 토큰이 없어도 앱은
/// 그대로 돈다. 여기서 던져서 Firebase 초기화를 통째로 깨뜨리면 안 된다.
Future<void> _activateAppCheck() async {
  try {
    AppLogger.i('[Bootstrap][AppCheck] start');
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      // App Attest는 iOS 14.0+에서만 된다. 그 아래는 DeviceCheck로 내려간다.
      providerApple: kReleaseMode
          ? const AppleAppAttestWithDeviceCheckFallbackProvider()
          : const AppleDebugProvider(),
    );
    AppLogger.i('[Bootstrap][AppCheck] success');
  } catch (e) {
    AppLogger.w('[Bootstrap][AppCheck] failed(넘어간다): $e');
  }
}

// 릴리즈 환경에서 Crashlytics 전역 핸들러를 연결한다.
void initCrashlytics() {
  try {
    AppLogger.i('[Bootstrap][Crashlytics] start');
    if (kReleaseMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    AppLogger.i('[Bootstrap][Crashlytics] success');
  } catch (e) {
    AppLogger.e('[Bootstrap][Crashlytics] failed', error: e);
  }
}
