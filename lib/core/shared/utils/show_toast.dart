import 'package:flutter/material.dart';
import 'app_logger.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 토스트 메시지 표시.
void showToast(String msg) {
  final messenger = scaffoldMessengerKey.currentState;
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
