import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';

ClipSegmentRef seg(String original, {int clip = 1, int start = 0}) =>
    ClipSegmentRef(
      clipId: clip,
      clipTitle: '클립$clip',
      segmentId: clip * 1000 + start,
      startMs: start,
      endMs: start + 2000,
      original: original,
    );

class FakeSource implements ClipSegmentSource {
  FakeSource(this.segments);
  final List<ClipSegmentRef> segments;

  @override
  Future<List<ClipSegmentRef>> loadSegments() async => segments;
}

void main() {
  test('같은 문장, 포함, 비슷한 문장 순으로 찾는다', () {
    final matches = matchClipSegments('How was your day?', [
      seg('Well, how was your day? Tell me.', clip: 2),
      seg('How was your day', clip: 1),
      seg('How was your dya?', clip: 3),
      seg('Nice weather today', clip: 4),
    ]);
    expect(matches.map((m) => m.segment.clipId), [1, 2, 3]);
    expect(matches.map((m) => m.kind),
        [ClipMatchKind.exact, ClipMatchKind.contains, ClipMatchKind.similar]);
  });

  test('공백, 문장부호, 대소문자는 무시한다', () {
    final matches =
        matchClipSegments('Hello there!', [seg('  HELLO,   there ')]);
    expect(matches.single.kind, ClipMatchKind.exact);
  });

  test('짧은 문장은 포함으로 판정하지 않는다', () {
    expect(matchClipSegments('Hi', [seg('Oh, hi there everyone')]), isEmpty);
    expect(
        matchClipSegments('Hi', [seg('hi!')]).single.kind, ClipMatchKind.exact);
  });

  test('일본어도 글자 단위로 찾는다', () {
    final matches = matchClipSegments('こんにちは', [seg('はい、こんにちは。元気ですか')]);
    expect(matches.single.kind, ClipMatchKind.contains);
  });

  test('같은 클립의 같은 구간 중복은 한 번만, 개수는 제한한다', () {
    final dup = matchClipSegments('Hello there', [
      seg('Hello there', start: 500),
      seg('Hello there', start: 500),
    ]);
    expect(dup, hasLength(1));
    final many = matchClipSegments(
        'Hello there',
        [
          for (var i = 0; i < 20; i++) seg('Hello there', clip: i),
        ],
        limit: 5);
    expect(many, hasLength(5));
  });

  test('빈 문장은 아무것도 찾지 않는다', () {
    expect(matchClipSegments('  !! ', [seg('Hello')]), isEmpty);
  });

  test('finder는 소스의 자막으로 찾고, 연결 전에는 준비 중 예외를 던진다', () async {
    final finder = ClipSentenceFinder(FakeSource([seg('Good morning')]));
    expect(
        (await finder.find('good morning')).single.kind, ClipMatchKind.exact);
    expect(
      const ClipSentenceFinder(UnavailableClipSegmentSource()).find('x'),
      throwsA(isA<ClipSearchUnavailable>()),
    );
  });
}
