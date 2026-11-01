import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/sentence_history_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('듣기와 따라 말하기가 쌓이면 대시보드 숫자가 바로 오른다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SentenceHistoryDashboard(
                    accountId: 'guest', language: '영어')))));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.textContaining('아직 연습한 문장이 없어요'), findsOneWidget);

    await tester.runAsync(() async {
      await SentenceActivityStore.incrementListen('guest', 'basic-en-001');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('1회'), findsOneWidget);
    expect(find.text('들은 횟수'), findsOneWidget);

    await tester.runAsync(() async {
      await SentenceActivityStore.incrementPractice('guest', 'basic-en-001');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('Hello there!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
