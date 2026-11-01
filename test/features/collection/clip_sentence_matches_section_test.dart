import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/clip_sentence_matches_section.dart';

class _Source implements ClipSegmentSource {
  _Source(this.segments);
  final List<ClipSegmentRef> segments;

  @override
  Future<List<ClipSegmentRef>> loadSegments() async => segments;
}

Widget app(ClipSentenceMatchesSection section) =>
    MaterialApp(home: Scaffold(body: section));

void main() {
  testWidgets('연결 전에는 준비 중 안내를 보여준다', (tester) async {
    await tester
        .pumpWidget(app(const ClipSentenceMatchesSection(sentence: 'Hello')));
    await tester.tap(find.byKey(const ValueKey('search-clips')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('아직 준비 중이에요'), findsOneWidget);
  });

  testWidgets('찾은 클립은 자막, 제목, 종류와 함께 보여준다', (tester) async {
    final finder = ClipSentenceFinder(_Source([
      const ClipSegmentRef(
          clipId: 1,
          clipTitle: '여행 브이로그',
          segmentId: 1,
          startMs: 65000,
          endMs: 67000,
          original: 'Hello there!'),
    ]));
    await tester.pumpWidget(app(
        ClipSentenceMatchesSection(sentence: 'hello there', finder: finder)));
    await tester.tap(find.byKey(const ValueKey('search-clips')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.text('여행 브이로그 · 1:05 · 같은 문장'), findsOneWidget);
  });

  testWidgets('맞는 클립이 없으면 없다고 알려준다', (tester) async {
    final finder = ClipSentenceFinder(_Source(const []));
    await tester.pumpWidget(
        app(ClipSentenceMatchesSection(sentence: 'Hello', finder: finder)));
    await tester.tap(find.byKey(const ValueKey('search-clips')));
    await tester.pump();
    await tester.pump();
    expect(find.text('이 문장이 들어간 클립이 없어요.'), findsOneWidget);
  });
}
