// 영상 파일이 없을 때 하는 말(5차 326).
//
// 전에는 어디서나 '영상 파일을 찾을 수 없어요.'였다. 서버에만 두고 이 기기로
// 아직 받지 않은 클립도 같은 말이 떠서, 무엇을 하면 되는지 알 수 없었다.

/// 서버에 둔 클립을 이 기기로 받지 않았을 때.
const String videoNotOnDeviceHint = '이 기기에 영상이 없어요. 보관함에서 먼저 받아 주세요.';

/// 기기에 있어야 할 파일이 없을 때(지웠거나 옮겼다).
const String videoMissingHint = '영상 파일을 찾을 수 없어요. 지웠거나 옮긴 것 같아요.';

/// [storageMode]는 clips 표의 값('local'·'server'·'gdrive').
String missingVideoHint(String storageMode) =>
    storageMode.trim() == 'server' ? videoNotOnDeviceHint : videoMissingHint;
