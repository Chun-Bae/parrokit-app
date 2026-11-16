// lib/core/bootstrap/bootstrap.dart
//
// [역할]
// 앱 초기화 부트스트랩 오케스트레이션.
//
// [레이어]
// Core Layer
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parrokit/core/app/app.dart';
import 'package:parrokit/core/app/bootstrap/bootstrap_dependencies.dart';
import 'package:parrokit/core/state/di/providers.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_messaging_service.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/data/local/prefs/intro_prefs.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/bootstrap/bootstrap_steps.dart';
import 'package:parrokit/core/infrastructure/services/local_notification_service.dart';

// 앱 시작 초기화 순서를 오케스트레이션한다.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.i('[Bootstrap][Start] app initialization');

  await initAppConfig();

  final themeProvider = await createThemeProvider();
  await ensureInternetOrShowOffline(themeProvider);

  await initFirebase();
  FirebaseMessagingService.registerBackgroundHandler();
  initCrashlytics();
  await initEnv();
  await initKakao();
  await initAudio();

  final userProvider = await createUserProvider();

  final seenIntro = await IntroPrefs.hasSeen();
  final router =
      buildAppRouter(seenIntro: seenIntro, userProvider: userProvider);

  // 연습 알림은 며칠치를 미리 예약해 두므로, 앱을 열 때마다 다시 채운다.
  // 알림이 꺼져 있으면 아무것도 하지 않는다. 화면을 막지 않게 기다리지 않는다.
  unawaited(refreshPracticeReminder(userProvider.currentUser?.id ?? 'guest'));

  await initAds();
  await initRevenueCat(userProvider);

  final iapProvider = await createIapProvider();
  final adProvider = createAdProvider(iapProvider: iapProvider);

  runApp(
    MultiProvider(
      providers: buildProviders(
        themeProvider: themeProvider,
        iapProvider: iapProvider,
        adProvider: adProvider,
        userProvider: userProvider,
      ),
      child: App(router: router),
    ),
  );

  // 커뮤니티 푸시를 눌러서 들어오는 길도 듣는다(5차 379). 서버가 보내는
  // routePath로 옮긴다.
  unawaited(FirebaseMessagingService().listenForNotificationTaps());

  // 알림을 눌러서 열렸으면 그 화면으로 옮긴다(5차 378). 화면이 올라온 뒤에
  // 해야 해서 기다리지 않고 띄운다.
  unawaited(LocalNotificationService.handleLaunchByNotification());

  AppLogger.i('[Bootstrap][Done] app started');
}
