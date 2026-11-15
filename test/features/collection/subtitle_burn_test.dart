// 자막을 구워 내보낼 때 쓰는 계산들(5차, 사용자 요청).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/export/domain/subtitle_burn.dart';

Segment seg({
  int id = 1,
  int start = 0,
  int end = 1000,
  String original = 'Hello',
  String pron = '헬로',
  String trans = '안녕',
}) =>
    Segment(
      id: id,
      clipId: 1,
      startMs: start,
      endMs: end,
      original: original,
      pron: pron,
      trans: trans,
    );

void main() {
  test('기본은 원문과 해석만 넣는다', () {
    expect(subtitleTextOf(seg(), const SubtitleBurnOptions()), 'Hello\n안녕');
  });

  test('발음을 켜면 원문 아래에 넣는다', () {
    expect(
        subtitleTextOf(
            seg(), const SubtitleBurnOptions(includePronunciation: true)),
        'Hello\n헬로\n안녕');
  });

  test('빈 줄은 넣지 않는다', () {
    expect(subtitleTextOf(seg(trans: '  '), const SubtitleBurnOptions()),
        'Hello');
    expect(
        subtitleTextOf(seg(original: '', trans: '안녕'),
            const SubtitleBurnOptions()),
        '안녕');
  });

  test('시각은 SRT 표기로 적는다', () {
    expect(srtTimestamp(0), '00:00:00,000');
    expect(srtTimestamp(1500), '00:00:01,500');
    expect(srtTimestamp(3661001), '01:01:01,001');
    expect(srtTimestamp(-5), '00:00:00,000', reason: '음수는 0으로 본다');
  });

  test('구간을 SRT로 만든다. 순서가 뒤섞여 있어도 시간순으로', () {
    final srt = buildSrt([
      seg(id: 2, start: 2000, end: 3000, original: 'Second', trans: '둘'),
      seg(id: 1, start: 0, end: 1000, original: 'First', trans: '하나'),
    ], const SubtitleBurnOptions());

    expect(srt, '''
1
00:00:00,000 --> 00:00:01,000
First
하나

2
00:00:02,000 --> 00:00:03,000
Second
둘
''');
  });

  test('글자가 없거나 길이가 0인 구간은 건너뛰고 번호를 다시 센다', () {
    final srt = buildSrt([
      seg(id: 1, start: 0, end: 0, original: 'Zero', trans: ''),
      seg(id: 2, start: 1000, end: 2000, original: '', pron: '', trans: ''),
      seg(id: 3, start: 3000, end: 4000, original: 'Third', trans: '셋'),
    ], const SubtitleBurnOptions());

    expect(srt.trim().split('\n').first, '1', reason: '번호가 비면 안 된다');
    expect(srt, contains('Third'));
    expect(srt, isNot(contains('Zero')));
  });

  test('넣을 자막이 하나도 없으면 빈 글자', () {
    expect(buildSrt(const [], const SubtitleBurnOptions()), '');
  });

  test('필터에 넣을 경로의 특수문자를 피한다', () {
    expect(escapeForFilter('/tmp/a b/sub.srt'), '/tmp/a b/sub.srt');
    expect(escapeForFilter("/tmp/it's:1.srt"), r"/tmp/it\'s\:1.srt");
  });

  test('ffmpeg 인자: 소리는 그대로 옮기고 앱 글꼴을 쓴다', () {
    final args = burnArguments(
      inputPath: '/tmp/in.mp4',
      subtitlePath: '/tmp/sub.srt',
      fontsDir: '/tmp/fonts',
      outputPath: '/tmp/out.mp4',
    );

    expect(args.first, '-y');
    expect(args, containsAllInOrder(['-i', '/tmp/in.mp4']));
    expect(args, containsAllInOrder(['-c:a', 'copy']));
    expect(args.last, '/tmp/out.mp4');
    final filter = args[args.indexOf('-vf') + 1];
    expect(filter, contains('subtitles='));
    expect(filter, contains('fontsdir='));
    expect(filter, contains('IBM Plex Sans KR'));
  });

  test('파일 이름은 제목을 쓰되 못 쓰는 글자를 걸러 낸다', () {
    final at = DateTime(2026, 11, 15, 22, 5);
    expect(exportFileName('카페에서/주문', at: at), '카페에서 주문_자막 20261115_2205.mp4');
    expect(exportFileName('   ', at: at), '클립_자막 20261115_2205.mp4');
    expect(exportFileName('가' * 60, at: at).length, lessThan(70));
  });

  test('얼마나 걸릴지 어림해서 알린다', () {
    expect(burnTimeHint(const Duration(seconds: 8)), '10초쯤 걸려요.');
    expect(burnTimeHint(const Duration(seconds: 60)), '30초쯤 걸려요.');
    expect(burnTimeHint(const Duration(minutes: 3)), '2분쯤 걸려요.');
  });
}
