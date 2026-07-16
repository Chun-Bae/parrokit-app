// unreachable_from_main 오탐: firebaseMessagingBackgroundHandler의
// @pragma('vm:entry-point') 때문에 이 파일이 "executable library"로
// 분류되어, 실제로는 bootstrap.dart/providers.dart에서 쓰이는
// FirebaseMessagingService 멤버들이 파일 내부 기준으로만 도달 불가 판정됨.
// ignore_for_file: unreachable_from_main

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:parrokit/core/app/config/firebase_options.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:flutter/services.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.d(
      '[CommunityNotification][FCM] background message received '
      'messageId=${message.messageId ?? "unknown"}',
    );
  } catch (e) {
    AppLogger.e('[CommunityNotification][FCM] background handler failed', error: e);
  }
}

class FirebaseMessagingService {
  final FirebaseMessaging _messaging;
  final FirebaseUserService _firebaseUserService;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentUserId;
  String? _currentToken;

  FirebaseMessagingService({
    FirebaseMessaging? messaging,
    FirebaseUserService? firebaseUserService,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firebaseUserService = firebaseUserService ?? FirebaseUserService();

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> syncUserToken(String userId) async {
    if (userId.isEmpty) return;

    try {
      final previousUserId = _currentUserId;
      final previousToken = _currentToken;

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.w(
          '[CommunityNotification][FCM] permission denied uid=$userId',
        );
        return;
      }

      if (Platform.isIOS || Platform.isMacOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        AppLogger.w(
          '[CommunityNotification][FCM] token unavailable uid=$userId',
        );
        return;
      }

      await _syncToken(
        userId: userId,
        token: token,
        previousUserId: previousUserId,
        previousToken: previousToken,
      );
      _startTokenRefreshListener();
    } on MissingPluginException catch (e) {
      AppLogger.w(
        '[CommunityNotification][FCM] plugin unavailable uid=$userId',
      );
      AppLogger.d(
        '[CommunityNotification][FCM] missing plugin detail=$e',
      );
      return;
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        AppLogger.w(
          '[CommunityNotification][FCM] APNs token not ready uid=$userId',
        );
        AppLogger.d(
          '[CommunityNotification][FCM] apns-token-not-set detail=$e',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> clearUserToken(String userId) async {
    if (userId.isEmpty || _currentToken == null) return;

    try {
      await _firebaseUserService.removeFcmToken(
        uid: userId,
        token: _currentToken!,
      );
      if (_currentUserId == userId) {
        _currentUserId = null;
        _currentToken = null;
      }
    } catch (e) {
      AppLogger.e('[CommunityNotification][FCM] clear token failed', error: e);
    }
  }

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    _tokenRefreshSubscription = null;
    _currentUserId = null;
    _currentToken = null;
  }

  Future<void> _syncToken({
    required String userId,
    required String token,
    String? previousUserId,
    String? previousToken,
  }) async {
    if (previousToken != null &&
        previousToken.isNotEmpty &&
        previousToken != token &&
        previousUserId != null &&
        previousUserId.isNotEmpty) {
      await _firebaseUserService.removeFcmToken(
        uid: previousUserId,
        token: previousToken,
      );
    }

    await _firebaseUserService.addFcmToken(uid: userId, token: token);
    _currentUserId = userId;
    _currentToken = token;
    AppLogger.d(
      '[CommunityNotification][FCM] token synced uid=$userId tokenLength=${token.length}',
    );
  }

  void _startTokenRefreshListener() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      (token) async {
        final userId = _currentUserId;
        if (userId == null || userId.isEmpty) return;

        try {
          await _syncToken(userId: userId, token: token);
        } catch (e) {
          AppLogger.e(
            '[CommunityNotification][FCM] token refresh sync failed',
            error: e,
          );
        }
      },
    );
  }
}
