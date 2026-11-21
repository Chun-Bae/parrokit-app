// 로그인한 사람의 정보를 한 사람으로 합치는 규칙(5차 385).
//
// 정보는 세 곳에서 온다. Firebase 인증(이름·메일·사진), 서버 문서(패롯·
// 크래커·안 읽은 알림·차단 목록), 기기에 적어 둔 캐시(서버에 못 닿을 때).
// 전에는 이 합치는 코드가 로그인 길마다 하나씩, 일곱 벌로 있었다. 그중
// 여섯 벌은 `lastNicknameChangedAt`을 빠뜨려서, 그 길로 로그인하면 닉네임을
// 바꾼 날짜가 사라지고 30일 제한이 풀린 것처럼 보였다.

import 'package:parrokit/data/models/user.dart';

/// 인증·서버·기기 정보를 하나로 합친다.
///
/// 고르는 차례는 늘 같다: 인증 → 서버 → 기기. 숫자는 없으면 0.
AppUser mergeAppUser({
  required String uid,
  String? authDisplayName,
  String? authEmail,
  String? authPhotoUrl,
  AppUser? server,
  AppUser? local,

  /// 만든 날짜가 어디에도 없을 때 지금으로 둘지. 회원가입 길에서 쓴다.
  bool createdAtDefaultsToNow = false,

  /// 메일이 어디에도 없을 때 빈 글로 둘지(null 대신).
  bool emailDefaultsToEmpty = false,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final email = authEmail ?? server?.email ?? local?.email;
  return AppUser(
    id: uid,
    displayName: authDisplayName ?? server?.displayName ?? local?.displayName,
    email: email ?? (emailDefaultsToEmpty ? '' : null),
    photoUrl: authPhotoUrl ?? server?.photoUrl ?? local?.photoUrl,
    parrots: server?.parrots ?? local?.parrots ?? 0,
    subParrots: server?.subParrots ?? local?.subParrots ?? 0,
    crackers: server?.crackers ?? local?.crackers ?? 0,
    unreadNotificationCount:
        server?.unreadNotificationCount ?? local?.unreadNotificationCount ?? 0,
    blockedUserIds: server?.blockedUserIds ?? local?.blockedUserIds ?? const [],
    createdAt: server?.createdAt ??
        local?.createdAt ??
        (createdAtDefaultsToNow ? at : null),
    updatedAt: at,
    // 닉네임을 바꾼 날짜는 30일 제한의 근거다. 어느 길로 로그인해도 지킨다.
    lastNicknameChangedAt:
        server?.lastNicknameChangedAt ?? local?.lastNicknameChangedAt,
  );
}
