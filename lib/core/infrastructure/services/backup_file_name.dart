/// 백업 파일 이름(5차, 사용자 요청 2026-11-17).
///
/// 전에는 `backup_20261117_124400.zip`이라 다른 앱이 만든 백업과 섞이면
/// 어느 것이 Parrokit 것인지 알 수 없었다. 음성 파일 이름과 같은 꼴로 맞춘다
/// (tts_file_name.dart의 `Parrokit_음성_…`).
String backupFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Parrokit_백업_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}.zip';
}

/// 앱 폴더에 남은 백업 찌꺼기인지. 예전 이름(`backup_…`)도 함께 본다.
/// 이름만 바꾸고 예전 것을 못 알아보면 지우지도, 빼지도 못해 백업 안에
/// 예전 백업이 통째로 들어간다.
bool isBackupFileName(String baseName) =>
    baseName.startsWith('Parrokit_백업_') || baseName.startsWith('backup_');
