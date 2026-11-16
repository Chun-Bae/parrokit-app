// 예외를 사람 말로 바꿀 때 쓰는 공통 판단(5차 310).
// 화면마다 따로 적으면 한 곳만 고쳐지고 나머지는 남는다. 규칙은 여기 하나다.

/// 인터넷이 끊겼을 때 Firestore·네트워크가 주는 글들.
bool looksOffline(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('unavailable') ||
      text.contains('offline') ||
      text.contains('socketexception') ||
      text.contains('network');
}

/// 서버 규칙이 막았을 때(로그인이 풀렸거나 남의 글을 건드렸을 때).
bool looksPermissionDenied(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('permission-denied') ||
      text.contains('permission denied') ||
      text.contains('unauthenticated');
}
