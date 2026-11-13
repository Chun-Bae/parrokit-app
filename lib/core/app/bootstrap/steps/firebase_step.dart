import 'dart:ui';

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

// 릴리즈 환경에서 Crashlytics 전역 핸들러를 연결한다.
void initCrashlytics() {
  try {
    AppLogger.i('[Bootstrap][Crashlytics] start');
    if (kReleaseMode) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
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
