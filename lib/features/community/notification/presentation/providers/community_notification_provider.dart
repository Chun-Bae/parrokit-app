import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_messaging_service.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/features/community/notification/domain/entities/community_notification_item.dart';
import 'package:parrokit/features/community/notification/domain/usecases/delete_all_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/delete_notification_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/fetch_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/watch_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/presentation/notification_error_text.dart';

class CommunityNotificationProvider extends ChangeNotifier {
  final WatchNotificationsUseCase _watchNotificationsUseCase;
  final FetchNotificationsUseCase _fetchNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;
  final MarkAllNotificationsReadUseCase _markAllNotificationsReadUseCase;
  final DeleteNotificationUseCase _deleteNotificationUseCase;
  final DeleteAllNotificationsUseCase _deleteAllNotificationsUseCase;
  final FirebaseMessagingService _messagingService;

  StreamSubscription<List<CommunityNotificationItem>>? _subscription;

  String? _currentUserId;
  bool _isLoading = false;
  String? _errorMessage;
  List<CommunityNotificationItem> _notifications = [];
  bool _isActive = false;

  CommunityNotificationProvider({
    required WatchNotificationsUseCase watchNotificationsUseCase,
    required FetchNotificationsUseCase fetchNotificationsUseCase,
    required MarkNotificationReadUseCase markNotificationReadUseCase,
    required MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase,
    required DeleteNotificationUseCase deleteNotificationUseCase,
    required DeleteAllNotificationsUseCase deleteAllNotificationsUseCase,
    required FirebaseMessagingService messagingService,
  })  : _watchNotificationsUseCase = watchNotificationsUseCase,
        _fetchNotificationsUseCase = fetchNotificationsUseCase,
        _markNotificationReadUseCase = markNotificationReadUseCase,
        _markAllNotificationsReadUseCase = markAllNotificationsReadUseCase,
        _deleteNotificationUseCase = deleteNotificationUseCase,
        _deleteAllNotificationsUseCase = deleteAllNotificationsUseCase,
        _messagingService = messagingService;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CommunityNotificationItem> get notifications => _notifications;
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  bool get hasNotifications => _notifications.isNotEmpty;

  void syncUser(String? userId) {
    final previousUserId = _currentUserId;

    if (_currentUserId == userId) {
      return;
    }

    _currentUserId = userId;
    _errorMessage = null;
    _notifications = [];
    _stopListening();

    if (userId == null || userId.isEmpty) {
      if (previousUserId != null && previousUserId.isNotEmpty) {
        unawaited(_messagingService.clearUserToken(previousUserId));
      }
      _messagingService.dispose();
      _isLoading = false;
      _notifyListenersSafe();
      return;
    }

    _notifyListenersSafe();
    unawaited(_messagingService.syncUserToken(userId));

    if (_isActive) {
      _isLoading = true;
      _notifyListenersSafe();
      unawaited(_initForUser(userId));
    }
  }

  Future<void> activate() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    if (_isActive) return;
    _isActive = true;
    _isLoading = true;
    _notifyListenersSafe();

    await _initForUser(userId);
  }

  Future<void> deactivate() async {
    _isActive = false;
    _stopListening();
    _isLoading = false;
  }

  Future<void> refresh() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    _isLoading = true;
    _notifyListenersSafe();

    try {
      final notifications = await _fetchNotificationsUseCase.execute(userId);
      // 기다리는 사이 계정이 바뀌었으면 이전 계정의 알림을 넣지 않는다.
      if (_currentUserId != userId) return;
      _notifications = notifications;
      _errorMessage = null;
    } catch (e) {
      if (_currentUserId != userId) return;
      _errorMessage = notificationErrorText(NotificationJob.load, e);
      AppLogger.e(
        '[CommunityNotification][Provider] refresh failed userId=$userId',
        error: e,
      );
    } finally {
      if (_currentUserId == userId) {
        _isLoading = false;
        _notifyListenersSafe();
      }
    }
  }

  /// 읽음으로 바꿨으면 true(5차 397).
  Future<bool> markAsRead(String notificationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty || notificationId.isEmpty) {
      return false;
    }

    try {
      await _markNotificationReadUseCase.execute(
        userId: userId,
        notificationId: notificationId,
      );
      _clearErrorAfterSuccess();
      return true;
    } catch (e) {
      _errorMessage = notificationErrorText(NotificationJob.read, e);
      AppLogger.e(
        '[CommunityNotification][Provider] markAsRead failed notificationId=$notificationId',
        error: e,
      );
      _notifyListenersSafe();
      return false;
    }
  }

  /// 다 읽음으로 바꿨으면 true(5차 397).
  Future<bool> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return false;

    try {
      await _markAllNotificationsReadUseCase.execute(userId);
      _clearErrorAfterSuccess();
      return true;
    } catch (e) {
      _errorMessage = notificationErrorText(NotificationJob.read, e);
      AppLogger.e(
        '[CommunityNotification][Provider] markAllAsRead failed userId=$userId',
        error: e,
      );
      _notifyListenersSafe();
      return false;
    }
  }

  /// 지웠으면 true. 화면은 이 값으로 밀어서 치울지 되돌릴지 정한다(5차 396).
  ///
  /// 예전에는 돌려주는 값이 없어, 화면이 `errorMessage`가 비었는지로
  /// 짐작했다. 앞서 다른 일로 난 오류가 남아 있으면 지웠는데도 실패로 봤다.
  Future<bool> deleteNotification(String notificationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty || notificationId.isEmpty) {
      return false;
    }

    try {
      await _deleteNotificationUseCase.execute(
        userId: userId,
        notificationId: notificationId,
      );
      _clearErrorAfterSuccess();
      return true;
    } catch (e) {
      _errorMessage = notificationErrorText(NotificationJob.delete, e);
      AppLogger.e(
        '[CommunityNotification][Provider] deleteNotification failed notificationId=$notificationId',
        error: e,
      );
      _notifyListenersSafe();
      return false;
    }
  }

  /// 다 지웠으면 true(5차 397). 화면은 이 값으로 알릴지 정한다.
  Future<bool> deleteAllNotifications() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return false;

    try {
      await _deleteAllNotificationsUseCase.execute(userId);
      _clearErrorAfterSuccess();
      return true;
    } catch (e) {
      _errorMessage = notificationErrorText(NotificationJob.delete, e);
      AppLogger.e(
        '[CommunityNotification][Provider] deleteAllNotifications failed userId=$userId',
        error: e,
      );
      _notifyListenersSafe();
      return false;
    }
  }

  /// 잘 끝났으면 앞서 뜬 빨간 안내를 치운다(5차 397).
  ///
  /// 전에는 한 번 실패하면 그 글이 화면 맨 위에 남아, 다음에 잘돼도 계속
  /// 떠 있었다. 목록이 새로 올 때(스트림)만 사라졌다.
  void _clearErrorAfterSuccess() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _notifyListenersSafe();
  }

  Future<void> _initForUser(String userId) async {
    try {
      final initialNotifications =
          await _fetchNotificationsUseCase.execute(userId);
      // 불러오는 사이 계정이 바뀌면(로그아웃 뒤 다른 계정 로그인) 예전엔
      // 이전 계정의 알림을 새 계정 화면에 넣고, 이전 계정의 실시간 구독까지
      // 붙여 둔 채 잃어버렸다(5차). 지금 계정의 요청이 아니면 버린다.
      if (_currentUserId != userId) return;
      _notifications = initialNotifications;

      if (!_isActive) {
        _isLoading = false;
        _notifyListenersSafe();
        return;
      }

      _stopListening();
      _subscription = _watchNotificationsUseCase.execute(userId).listen(
        (items) {
          if (!_isActive || _currentUserId != userId) return;
          _notifications = items;
          _errorMessage = null;
          _isLoading = false;
          _notifyListenersSafe();
        },
        onError: (error) {
          _errorMessage = notificationErrorText(NotificationJob.load, error);
          _isLoading = false;
          AppLogger.e(
            '[CommunityNotification][Provider] watch stream failed userId=$userId',
            error: error,
          );
          _notifyListenersSafe();
        },
      );
    } catch (e) {
      if (_currentUserId != userId) return;
      _errorMessage = notificationErrorText(NotificationJob.load, e);
      AppLogger.e(
        '[CommunityNotification][Provider] init failed userId=$userId',
        error: e,
      );
    } finally {
      if (_currentUserId == userId) {
        _isLoading = false;
        _notifyListenersSafe();
      }
    }
  }

  void _stopListening() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _notifyListenersSafe() {
    if (_isActive && hasListeners) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopListening();
    _messagingService.dispose();
    super.dispose();
  }
}
