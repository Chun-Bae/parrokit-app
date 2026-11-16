// 사용자가 파일 고르기·저장을 그만둔 것(5차 362).
//
// 전에는 이것도 Exception으로 던져서 '안 됐어요 / 불러오지 못했어요' 빨간
// 화면이 떴다. 사용자가 스스로 그만둔 것은 실패가 아니라서, 따로 알아보고
// 창을 처음 단계로 돌려놓는다.
class BackupCancelled implements Exception {
  const BackupCancelled();

  @override
  String toString() => 'BackupCancelled';
}

/// 백업 파일을 저장하려 한 결과.
enum BackupSaveResult {
  /// 저장했다.
  saved,

  /// 사용자가 저장 창을 닫았다.
  cancelled,

  /// 저장하다 실패했다.
  failed,
}
