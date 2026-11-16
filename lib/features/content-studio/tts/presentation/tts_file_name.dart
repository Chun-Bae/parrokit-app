/// 내려받는 음성 파일 이름(5차 411).
///
/// 전에는 작은따옴표 문자열 안에서 `\$`를 escape 해서,
/// 파일이 `Parrokit_TTS_${DateTime.now().millisecondsSinceEpoch}`라는
/// 글자 그대로 저장됐다. 날짜가 들어가지 않아 여러 번 내려받으면 어느 것이
/// 어느 것인지도 알 수 없었다.
String ttsFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Parrokit_음성_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}
