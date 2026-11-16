// lib/data/local/prefs/userprefs.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/data/models/user.dart';

/// 앱 로컬에 "현재 유저"의 최소 정보를 저장/로드하는 헬퍼.
///
/// 여기서는:
/// - userId
/// - displayName
/// - email
/// - parrots (패롯)
/// - crackers (크래커)
/// 정도만 다룹니다.
/// 실제 도메인 데이터는 Firestore 등에서 관리하고,
/// 이 클래스는 로그인/식별 및 UI 초기 로딩 속도 향상을 위한 로컬 캐시로 사용합니다.
class UserPrefs {
  static const _keyUserId = 'user.id';
  static const _keyDisplayName = 'user.displayName';
  static const _keyEmail = 'user.email';
  static const _keyPhotoUrl = 'user.photoUrl';
  static const _keyParrots = 'user.parrots';
  static const _keyCrackers = 'user.crackers';
  static const _keyUnreadNotificationCount = 'user.unreadNotificationCount';
  static const _keyBlockedUserIds = 'user.blockedUserIds';
  static const _keyLastNicknameChangedAt = 'user.lastNicknameChangedAt';

  /// 저장소. 아주 드물게 SharedPreferences를 열지 못하면 null이 온다(5차 374).
  ///
  /// 전에는 그 경우 부트스트랩이 `UserPrefs(null as dynamic)`을 넘겼다. 그러면
  /// 읽거나 쓰려는 순간 앱이 멈췄다. 저장소가 없으면 읽기는 비어 있는 것으로,
  /// 쓰기는 아무 일도 하지 않는 것으로 둔다. 로그인 정보만 기억하지 못한다.
  final SharedPreferences? _prefs;

  UserPrefs(this._prefs);

  /// 현재 로컬에 저장된 유저가 있다면 AppUser로 복원합니다.
  /// userId가 없으면 "로그인된 유저 없음"으로 간주하고 null을 반환합니다.
  AppUser? loadUser() {
    final prefs = _prefs;
    if (prefs == null) return null;
    final id = prefs.getString(_keyUserId);
    if (id == null || id.isEmpty) {
      return null;
    }

    final displayName = prefs.getString(_keyDisplayName);
    final email = prefs.getString(_keyEmail);
    final photoUrl = prefs.getString(_keyPhotoUrl);
    final parrots = prefs.getInt(_keyParrots) ?? 0;
    final crackers = prefs.getInt(_keyCrackers) ?? 0;
    final unreadNotificationCount = prefs.getInt(_keyUnreadNotificationCount) ?? 0;
    final blockedUserIds = prefs.getStringList(_keyBlockedUserIds) ?? const [];
    
    final lastNicknameStr = prefs.getString(_keyLastNicknameChangedAt);
    final lastNicknameChangedAt = lastNicknameStr != null ? DateTime.tryParse(lastNicknameStr) : null;

    return AppUser(
      id: id,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      parrots: parrots,
      crackers: crackers,
      unreadNotificationCount: unreadNotificationCount,
      blockedUserIds: blockedUserIds,
      lastNicknameChangedAt: lastNicknameChangedAt,
    );
  }

  /// 현재 유저 정보를 통째로 저장합니다.
  Future<void> saveUser(AppUser user) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_keyUserId, user.id);
    if (user.displayName != null) {
      await prefs.setString(_keyDisplayName, user.displayName!);
    } else {
      await prefs.remove(_keyDisplayName);
    }

    if (user.email != null) {
      await prefs.setString(_keyEmail, user.email!);
    } else {
      await prefs.remove(_keyEmail);
    }

    if (user.photoUrl != null) {
      await prefs.setString(_keyPhotoUrl, user.photoUrl!);
    } else {
      await prefs.remove(_keyPhotoUrl);
    }

    await prefs.setInt(_keyParrots, user.parrots);
    await prefs.setInt(_keyCrackers, user.crackers);
    await prefs.setInt(_keyUnreadNotificationCount, user.unreadNotificationCount);
    await prefs.setStringList(_keyBlockedUserIds, user.blockedUserIds);

    if (user.lastNicknameChangedAt != null) {
      await prefs.setString(_keyLastNicknameChangedAt, user.lastNicknameChangedAt!.toIso8601String());
    } else {
      await prefs.remove(_keyLastNicknameChangedAt);
    }
  }

  /// 로컬에 저장된 유저 정보를 모두 제거합니다.
  Future<void> clear() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await Future.wait([
      prefs.remove(_keyUserId),
      prefs.remove(_keyDisplayName),
      prefs.remove(_keyEmail),
      prefs.remove(_keyPhotoUrl),
      prefs.remove(_keyParrots),
      prefs.remove(_keyCrackers),
      prefs.remove(_keyUnreadNotificationCount),
      prefs.remove(_keyBlockedUserIds),
      prefs.remove(_keyLastNicknameChangedAt),
    ]);
  }
}
