import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/trending_sentences_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sentence_seed.dart';

late FakeFirebaseFirestore firestore;
late FirestoreSharedSentenceRepository repo;

Widget app({String language = '영어'}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TrendingSentencesPreview(
            language: language,
            onViewAll: () {},
            repository: repo,
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSharedSentenceRepository(firestore: firestore);
  });

  testWidgets('공유된 문장을 좋아요 순으로 작성자와 함께 보여준다', (tester) async {
    await seedSentence(firestore, 'a',
        visibility: 'public', text: 'Less liked', likeCount: 1);
    await seedSentence(firestore, 'b',
        visibility: 'public',
        text: 'Most liked',
        likeCount: 7,
        ownerId: 'mina',
        authorName: 'Mina');
    await seedSentence(firestore, 'c', text: 'Private one', likeCount: 99);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Private one'), findsNothing);
    final most = tester.getTopLeft(find.text('Most liked'));
    final less = tester.getTopLeft(find.text('Less liked'));
    expect(most.dx, lessThan(less.dx));
    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    // 예시로 박혀 있던 가짜 데이터는 더 이상 없다.
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('@dailybird'), findsNothing);
  });

  testWidgets('공유된 문장이 없으면 보관함으로 안내한다', (tester) async {
    await tester.pumpWidget(app(language: '일본어'));
    await tester.pumpAndSettle();
    expect(find.text('아직 공유된 일본어 문장이 없어요'), findsOneWidget);
    expect(find.text('보관함으로'), findsOneWidget);
  });

  testWidgets('저장 버튼을 누르면 내 문장에 들어간다', (tester) async {
    await seedSentence(firestore, 'b',
        visibility: 'public', text: 'Save me', ownerId: 'mina');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('내 문장에 저장'));
    await tester.pumpAndSettle();

    final mine = await MySentenceStore.load('guest');
    expect(mine.map((e) => e.text), ['Save me']);
    expect(find.byTooltip('내 문장에서 빼기'), findsOneWidget);
  });
}
