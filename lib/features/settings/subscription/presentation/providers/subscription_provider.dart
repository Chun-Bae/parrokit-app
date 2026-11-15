// 지금 사람의 구독 단계를 들고 있는 곳.
//
// 정하는 것은 서버다(users/{uid}.subscription). 앱은 그 문서를 지켜보기만
// 한다. 서버에 아직 값이 없으면 RevenueCat이 들고 있는 entitlement를 쓰고,
// 그것도 없으면 무료로 본다(5차).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool _disposed = false;

  SubscriptionState _server = SubscriptionState.free;
  bool _serverLoaded = false;

  /// RevenueCat이 들고 있는 entitlement로 본 상태. 아직 모르면 null.
  SubscriptionState? _revenueCat;

  SubscriptionState get state => resolveSubscription(
        server: _serverLoaded ? _server : null,
        revenueCat: _revenueCat,
      );

  SubscriptionTier get tier => state.tier;
  bool get isSubscribed => state.isActive;

  /// 로그인한 사람이 바뀌면 지켜보는 문서도 바꾼다.
  void syncUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _server = SubscriptionState.free;
    _serverLoaded = false;
    if (uid == null || uid.isEmpty) {
      _notify();
      return;
    }
    _sub = _firestore.collection('users').doc(uid).snapshots().listen(
      (snapshot) {
        final map = snapshot.data()?['subscription'];
        _server = subscriptionFromServer(
            map is Map ? Map<String, dynamic>.from(map) : null);
        // 문서는 있는데 subscription 칸이 없으면 서버가 아직 정하지 않은
        // 것이다. 그때는 RevenueCat 값을 쓴다.
        _serverLoaded = map is Map;
        _notify();
      },
      onError: (Object error) {
        AppLogger.w('[Subscription] 구독 상태를 읽지 못했어요: $error');
        _serverLoaded = false;
        _notify();
      },
    );
  }

  /// RevenueCat에서 받은 활성 entitlement 이름들.
  void applyEntitlements(Set<String> active) {
    _revenueCat = subscriptionFromEntitlements(active);
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
