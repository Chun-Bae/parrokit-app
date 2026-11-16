// 탈퇴를 시작해도 되는지 먼저 본다(5차 386).
//
// 탈퇴는 사용자 문서를 지운 뒤 Firebase 계정을 지운다. 그런데 계정 삭제는
// 로그인한 지 오래되면 Firebase가 'requires-recent-login'으로 거절한다.
// 그러면 문서(패롯·크래커·차단 목록·알림 설정)는 이미 사라졌는데 계정은
// 남아, 사용자는 '탈퇴하지 못했어요'만 보고 자료를 잃는다.
//
// 그래서 지우기 전에 로그인한 지 얼마나 됐는지 보고, 오래됐으면 아무것도
// 지우지 않고 멈춘다.

/// Firebase가 다시 로그인을 요구하기 전까지 보는 시간. 넉넉히 짧게 잡는다.
const Duration recentLoginWindow = Duration(minutes: 5);

/// 다시 로그인해야 하면 true. [lastSignInAt]을 모르면 안전하게 true.
bool needsRecentLoginToDelete(
  DateTime? lastSignInAt,
  DateTime now, {
  Duration window = recentLoginWindow,
}) {
  if (lastSignInAt == null) return true;
  return now.difference(lastSignInAt) > window;
}

/// 멈출 때 사용자에게 보여 줄 말.
const String recentLoginNeededMessage = '보안을 위해 다시 로그인한 뒤 탈퇴할 수 있어요.';
