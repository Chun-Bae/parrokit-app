/// 문장·단어를 파일로 주고받을 때 쓰는 이름(사용자 요청 2026-11-17).
///
/// 백업(`Parrokit_백업_…`)·음성(`Parrokit_음성_…`)과 같은 꼴로 맞춘다.
String studyFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'Parrokit_문장단어_${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
}
