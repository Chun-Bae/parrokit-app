// 자막 넣어 내보내기 화면의 흐름: 안내 → 진행률 → 공유, 그리고 실패와 취소.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/export/data/subtitle_burn_service.dart';
import 'package:parrokit/features/collection/clip/export/domain/subtitle_burn.dart';
import 'package:parrokit/features/collection/clip/export/presentation/subtitle_export_sheet.dart';

/// 실제로 굽지 않고 결과만 돌려주는 가짜.
class _FakeBurnService implements SubtitleBurnService {
  _FakeBurnService({this.result = const SubtitleBurnResult(path: '/tmp/a.mp4')});

  SubtitleBurnResult result;
  final completer = Completer<SubtitleBurnResult>();
  bool useCompleter = false;
  int canceled = 0;
  void Function(double)? lastProgress;

  @override
  Future<SubtitleBurnResult> burn({
    required String videoPath,
    required List<Segment> segments,
    required String clipTitle,
    required Duration videoLength,
    SubtitleBurnOptions options = const SubtitleBurnOptions(),
    void Function(double progress)? onProgress,
  }) {
    lastProgress = onProgress;
    return useCompleter ? completer.future : Future.value(result);
  }

  @override
  Future<void> cancel() async {
    canceled++;
    if (useCompleter && !completer.isCompleted) {
      completer.complete(const SubtitleBurnResult(canceled: true));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _FakeBurnService service) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(MaterialApp(
    theme:
        ThemeData(colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
    home: Scaffold(
      body: SubtitleExportSheet(
        videoPath: '/tmp/in.mp4',
        segments: const [],
        clipTitle: '카페에서',
        videoLength: const Duration(minutes: 1),
        service: service,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('시작하기 전에 무엇을 하는지와 얼마나 걸리는지 알린다', (tester) async {
    await _open(tester, _FakeBurnService());

    expect(find.text(subtitleExportTitle), findsOneWidget);
    expect(find.textContaining('나중에 고칠 수 없어요'), findsOneWidget);
    expect(find.textContaining('30초쯤 걸려요'), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-export-start')), findsOneWidget);
  });

  testWidgets('만드는 동안 진행률과 그만두기가 보인다', (tester) async {
    final service = _FakeBurnService()..useCompleter = true;
    await _open(tester, service);

    await tester.tap(find.byKey(const ValueKey('subtitle-export-start')));
    await tester.pump();

    expect(find.text(subtitleExportRunningText), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-export-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-export-cancel')), findsOneWidget);

    service.lastProgress!(0.4);
    await tester.pump();
    expect(find.text('40%'), findsOneWidget);

    service.completer.complete(const SubtitleBurnResult(path: '/tmp/a.mp4'));
    await tester.pump();
    expect(find.text(subtitleExportDoneText), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-export-share')), findsOneWidget);
  });

  testWidgets('그만두기를 누르면 굽던 것을 멈춘다', (tester) async {
    final service = _FakeBurnService()..useCompleter = true;
    await _open(tester, service);
    await tester.tap(find.byKey(const ValueKey('subtitle-export-start')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('subtitle-export-cancel')));
    await tester.pump();

    expect(service.canceled, 1);
  });

  testWidgets('실패하면 까닭을 보여 주고 다시 시도할 수 있다', (tester) async {
    final service = _FakeBurnService(
        result: const SubtitleBurnResult(message: '넣을 자막이 없어요.'));
    await _open(tester, service);

    await tester.tap(find.byKey(const ValueKey('subtitle-export-start')));
    await tester.pump();

    expect(find.text('넣을 자막이 없어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('subtitle-export-retry')), findsOneWidget);
  });
}
