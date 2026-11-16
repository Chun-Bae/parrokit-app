/// 폴더 이름 규칙과, 만들 수 없을 때의 까닭(5차 316).
///
/// 전에는 이름이 비었거나 바뀐 것이 없으면 '만들기'가 흐리게 꺼지기만 했다.
/// 눌러도 아무 일이 없어서 무엇이 모자란지 알 수 없었다.
String? folderNameBlockedReason(
  String name, {
  bool renaming = false,
  String? initialName,
}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '폴더 이름을 적어 주세요.';
  if (name.contains('/')) return "폴더 이름에 '/'는 쓸 수 없어요.";
  if (renaming && trimmed == (initialName ?? '')) {
    return '이름이 그대로예요. 바꿀 이름을 적어 주세요.';
  }
  return null;
}
