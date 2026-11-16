import 'package:flutter/material.dart';
import 'app_logger.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 토스트 메시지 표시.
///
/// 화면이 아직 없거나(앱 시작 전) 테스트처럼 바인딩이 없는 데서 불러도
/// 터지지 않는다. 알리지 못하면 로그만 남긴다(5차 382).
void showToast(String msg) {
  ScaffoldMessengerState? messenger;
  try {
    messenger = scaffoldMessengerKey.currentState;
  } catch (error) {
    AppLogger.w('🍞 Toast (no binding): $msg');
    return;
  }
  if (messenger == null) {
    AppLogger.w('🍞 Toast (no messenger): $msg');
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2500),
        // margin은 floating일 때만 쓸 수 있다. 테마가 floating이 아닌 곳에서는
        // SnackBar를 만들다 멈춰(assertion) 아무것도 안 보였다(5차).
        // 여기서 직접 정해 테마와 상관없이 뜨게 한다.
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      ),
    );

  AppLogger.d('[🍞] $msg');
}
