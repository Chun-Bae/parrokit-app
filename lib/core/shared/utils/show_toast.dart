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
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 80),
      ),
    );

  AppLogger.d('[🍞] $msg');
}
