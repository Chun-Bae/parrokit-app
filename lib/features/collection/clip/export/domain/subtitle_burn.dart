// 클립에 자막을 구워 새 영상을 만드는 데 쓰는 계산들(5차, 사용자 요청).
//
// 백업과는 다른 일이다. 백업은 앱으로 되돌리는 것이고, 이것은 앱 밖으로
// 가지고 나가는 것이다. 한 번 구우면 자막을 고칠 수 없고 영상도 다시
// 인코딩되므로, 클립 하나씩 따로 한다.
//
// 여기에는 파일을 건드리는 코드가 없다. 글자 만들기와 명령 조립만 두고
// 테스트한다. 실제 실행은 SubtitleBurnService가 한다.

import 'package:parrokit/data/local/app_database.dart';

/// 자막에 무엇을 넣을지. 처음에는 원문과 해석 둘만 둔다(설정이 늘면 화면이 커진다).
class SubtitleBurnOptions {
  const SubtitleBurnOptions({
    this.includeTranslation = true,
    this.includePronunciation = false,
  });

  final bool includeTranslation;
  final bool includePronunciation;
}

/// 한 구간이 자막으로 보일 글자. 원문이 비면 빈 문자열.
String subtitleTextOf(Segment segment, SubtitleBurnOptions options) {
  final lines = <String>[
    segment.original.trim(),
    if (options.includePronunciation) segment.pron.trim(),
    if (options.includeTranslation) segment.trans.trim(),
  ].where((line) => line.isNotEmpty).toList();
  return lines.join('\n');
}

/// SRT가 쓰는 시각 표기(00:00:01,500).
String srtTimestamp(int milliseconds) {
  final ms = milliseconds < 0 ? 0 : milliseconds;
  String two(int v) => v.toString().padLeft(2, '0');
  final hours = ms ~/ 3600000;
  final minutes = (ms % 3600000) ~/ 60000;
  final seconds = (ms % 60000) ~/ 1000;
  final millis = (ms % 1000).toString().padLeft(3, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)},$millis';
}

/// 구간들을 SRT 글자로 만든다. 글자가 없는 구간과 길이가 0인 구간은 건너뛴다.
///
/// 번호는 1부터 다시 센다. 건너뛴 구간 때문에 번호가 비면 플레이어에 따라
/// 자막을 통째로 버리는 것이 있다.
String buildSrt(List<Segment> segments, SubtitleBurnOptions options) {
  final sorted = [...segments]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final blocks = <String>[];
  for (final segment in sorted) {
    final text = subtitleTextOf(segment, options);
    if (text.isEmpty || segment.endMs <= segment.startMs) continue;
    blocks.add('${blocks.length + 1}\n'
        '${srtTimestamp(segment.startMs)} --> ${srtTimestamp(segment.endMs)}\n'
        '$text');
  }
  return blocks.isEmpty ? '' : '${blocks.join('\n\n')}\n';
}

/// ffmpeg 필터 안에 넣을 때 탈 나는 글자를 피한다.
/// 경로에 따옴표나 콜론이 있으면 필터가 끊긴다.
String escapeForFilter(String path) => path
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(':', r'\:')
    .replaceAll(',', r'\,')
    .replaceAll('[', r'\[')
    .replaceAll(']', r'\]');

/// 자막에 쓸 글꼴 이름. **파일 안에 적힌 이름과 한 글자도 달라서는 안 된다.**
///
/// 'IBM Plex Sans KR'로 넘겼더니 libass가 못 찾아 다른 글꼴로 떨어졌고,
/// 그 글꼴에 한글이 없는 기기에서는 자막이 깨져 나왔다(5차, 사용자 신고).
/// 시뮬레이터에는 한글 글꼴이 있어 멀쩡해 보여서 늦게 드러났다.
const String burnFontFamily = 'IBM Plex Sans KR SemiBold';

/// 자막을 구울 ffmpeg 인자.
///
/// - 글꼴은 앱이 들고 있는 것을 쓴다. 기기 글꼴을 찾게 두면 한글이 깨진다
/// - 소리는 그대로 옮긴다(-c:a copy). 다시 인코딩할 까닭이 없다
/// - 이미 있는 파일은 덮어쓴다(-y). 같은 클립을 두 번 내보낼 수 있다
List<String> burnArguments({
  required String inputPath,
  required String subtitlePath,
  required String fontsDir,
  required String outputPath,
  String fontName = burnFontFamily,
  int fontSize = 18,
}) {
  final style = 'FontName=$fontName,FontSize=$fontSize,'
      'PrimaryColour=&H00FFFFFF,OutlineColour=&H80000000,'
      'BorderStyle=3,Outline=2,Shadow=0,Alignment=2,MarginV=36';
  final filter = "subtitles='${escapeForFilter(subtitlePath)}'"
      ":fontsdir='${escapeForFilter(fontsDir)}'"
      ":force_style='$style'";
  return [
    '-y',
    '-i',
    inputPath,
    '-vf',
    filter,
    '-c:a',
    'copy',
    '-movflags',
    '+faststart',
    outputPath,
  ];
}

/// 내보낼 파일 이름. 제목이 비었거나 파일 이름에 못 쓰는 글자면 걸러 낸다.
String exportFileName(String clipTitle, {DateTime? at}) {
  final cleaned = clipTitle
      .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final time = at ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp = '${time.year}${two(time.month)}${two(time.day)}'
      '_${two(time.hour)}${two(time.minute)}';
  final base = cleaned.isEmpty ? '클립' : cleaned;
  // 이름이 너무 길면 파일 시스템이 거부한다.
  final short = base.length > 40 ? base.substring(0, 40).trim() : base;
  return '$short _자막 $stamp.mp4'.replaceAll(' _', '_');
}

/// 얼마나 걸릴지 어림한 말. 1분 영상에 30초쯤 걸린다고 본다.
String burnTimeHint(Duration videoLength) {
  final seconds = (videoLength.inSeconds / 2).round();
  if (seconds <= 10) return '10초쯤 걸려요.';
  if (seconds < 60) return '$seconds초쯤 걸려요.';
  final minutes = (seconds / 60).ceil();
  return '$minutes분쯤 걸려요.';
}
