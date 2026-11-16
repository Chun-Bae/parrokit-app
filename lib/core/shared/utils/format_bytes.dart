// 바이트를 사람이 읽는 크기로 적는다(5차 363).
//
// 같은 함수가 세 화면(더보기 데이터 칸·받아 둔 영상·저장 용량)에 그대로
// 복사돼 있었다. 한 곳만 고치면 화면마다 다르게 보이게 되므로 한 곳으로 모은다.

/// 예: 0 B, 980 B, 1.4 KB, 12 MB, 1.2 GB.
///
/// 10 이상이거나 바이트 단위면 소수점을 떼고, 그보다 작으면 한 자리 남긴다.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
}
