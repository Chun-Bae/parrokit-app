// lib/data/models/user.dart

/// 대표적인 앱 사용자 모델.
/// - id          : 유저를 구분하는 고유 ID (예: Firebase UID, 로컬 UUID 등)
/// - displayName : 화면에 표시할 이름
/// - email       : 로그인 이메일 (없을 수도 있음)
/// - photoUrl    : 프로필 이미지 URL (없을 수도 있음)
/// - parrots     : 유저가 보유한 패롯 수 (기본값 0)
/// - unreadNotificationCount: 읽지 않은 알림 수
/// - blockedUserIds: 차단한 유저 ID 목록
/// - createdAt   : 계정이 처음 생성된 시각 (없으면 null)
/// - updatedAt   : 마지막으로 정보가 갱신된 시각 (없으면 null)
class AppUser {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final int parrots;
  final int crackers;

  /// 구독으로 매달 받는 패롯. 보통 패롯과 따로 센다(5차).
  ///
  /// 쓸 때는 서버가 이쪽부터 깎고, 기간이 끝나면 사라진다. 환전은 안 된다.
  final int subParrots;
  final int unreadNotificationCount;
  final List<String> blockedUserIds;

  /// 지금 쓸 수 있는 패롯. 구독으로 받은 것까지 더한 값이다.
  int get spendableParrots => parrots + subParrots;

  /// 하위 호환성 (기존 코인 시스템과 패롯을 동일 취급).
  /// 쓸 수 있는지 보는 자리에서 쓰므로 구독 패롯까지 센다.
  int get coins => spendableParrots;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastNicknameChangedAt;

  const AppUser({
    required this.id,
    this.displayName,
    this.email,
    this.photoUrl,
    this.parrots = 20,
    this.crackers = 1000,
    this.subParrots = 0,
    this.unreadNotificationCount = 0,
    this.blockedUserIds = const [],
    this.createdAt,
    this.updatedAt,
    this.lastNicknameChangedAt,
  });

  /// 재화 증감이 적용된 새 인스턴스를 반환합니다.
  AppUser addParrots(int delta) {
    return copyWith(parrots: parrots + delta);
  }

  AppUser addCrackers(int delta) {
    return copyWith(crackers: crackers + delta);
  }

  // 기존 호환용 메서드
  AppUser addCoins(int delta) => addParrots(delta);

  /// 일부 필드만 변경해서 새 인스턴스를 만들기 위한 헬퍼입니다.
  AppUser copyWith({
    String? id,
    String? displayName,
    bool clearDisplayName = false,
    String? email,
    String? photoUrl,
    bool clearPhotoUrl = false,
    int? parrots,
    int? crackers,
    int? subParrots,
    int? unreadNotificationCount,
    List<String>? blockedUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastNicknameChangedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      email: email ?? this.email,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      parrots: parrots ?? this.parrots,
      crackers: crackers ?? this.crackers,
      subParrots: subParrots ?? this.subParrots,
      unreadNotificationCount:
          unreadNotificationCount ?? this.unreadNotificationCount,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastNicknameChangedAt:
          lastNicknameChangedAt ?? this.lastNicknameChangedAt,
    );
  }

  /// JSON → AppUser
  /// Firestore, REST API 등에서 내려오는 JSON을 그대로 매핑할 때 사용합니다.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      photoUrl: json['photoUrl'] as String?,
      parrots: (json['parrots'] as num?)?.toInt() ??
          (json['coins'] as num?)?.toInt() ??
          0,
      crackers: (json['crackers'] as num?)?.toInt() ?? 0,
      subParrots: (json['subParrots'] as num?)?.toInt() ?? 0,
      unreadNotificationCount:
          (json['unreadNotificationCount'] as num?)?.toInt() ?? 0,
      blockedUserIds: (json['blockedUserIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((id) => id.isNotEmpty)
              .toList() ??
          const [],
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      lastNicknameChangedAt: _parseDateTime(json['lastNicknameChangedAt']),
    );
  }

  /// AppUser → JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'parrots': parrots,
      'crackers': crackers,
      'subParrots': subParrots,
      'unreadNotificationCount': unreadNotificationCount,
      'blockedUserIds': blockedUserIds,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastNicknameChangedAt': lastNicknameChangedAt?.toIso8601String(),
    };
  }

  /// createdAt/updatedAt 등에 들어올 수 있는 값을 DateTime으로 변환하는 유틸.
  /// - DateTime
  /// - String (ISO8601)
  /// - Timestamp(ms) 형태 num
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is num) {
      // ms 기준 타임스탬프라고 가정
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  @override
  String toString() {
    return 'AppUser(id: $id, displayName: $displayName, email: $email, photoUrl: $photoUrl, parrots: $parrots, crackers: $crackers, unreadNotificationCount: $unreadNotificationCount, blockedUserIds: $blockedUserIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser &&
        other.id == id &&
        other.displayName == displayName &&
        other.email == email &&
        other.photoUrl == photoUrl &&
        other.parrots == parrots &&
        other.crackers == crackers &&
        other.unreadNotificationCount == unreadNotificationCount &&
        _sameBlockedUsers(other.blockedUserIds, blockedUserIds) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      displayName,
      email,
      photoUrl,
      parrots,
      crackers,
      unreadNotificationCount,
      Object.hashAll(blockedUserIds),
      createdAt,
      updatedAt,
    );
  }

  static bool _sameBlockedUsers(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
