import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

late FirestoreSharedSentenceRepository repo;

Widget app() => MaterialApp(
    home: Scaffold(body: SentenceCollectionPreview(repository: repo)));

/// 다른 사람이 공유한 문장 하나를 서버에 넣어 둔다.
Future<void> seedShared() => repo.publish(
      localSentenceId: 'my-1',
      authorId: 'mina',
      authorName: 'Mina',
      language: '영어',
      text: 'Could I get this to go?',
      translation: '이거 포장해 주실 수 있나요?',
      pronunciation: '',
      topic: '카페',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo =
        FirestoreSharedSentenceRepository(firestore: FakeFirebaseFirestore());
  });

  testWidgets('추가한 문장이 내 문장 목록에 나타난다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('문장 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Brand new sentence');
    await tester.enterText(
        find.byKey(const ValueKey('sentence-translation')), '완전 새로운 문장');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-sentence')));
    await tester.pumpAndSettle();

    expect(
        find.text('Brand new sentence', skipOffstage: false), findsOneWidget);
  });

  testWidgets('둘러보기에서 저장한 문장이 내 문장에 나타난다', (tester) async {
    await seedShared();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).length, 1);

    await tester.scrollUntilVisible(find.text('내 문장'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    expect(find.text('Could I get this to go?', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('문장 상세 시트의 마이크 버튼을 눌러도 안전하다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello there!'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('문장 듣기'), findsOneWidget);
    // 플러그인이 없는 테스트 환경에서도 예외 없이 동작한다.
    await tester.tap(find.byTooltip('문장 듣기'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('문장 상세에 닉네임이 보이고 좋아요가 저장된다', (tester) async {
    await MySentenceStore.add('guest',
        language: '영어',
        text: 'Liked sentence',
        translation: '좋아요 문장',
        author: '앵무');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liked sentence'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sentence-author')), findsOneWidget);
    expect(find.text('앵무'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('like-sentence')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('좋아요 취소'), findsOneWidget);
    final id = MySentenceStore.idFor('영어', 'Liked sentence');
    expect((await SentenceActivityStore.load('guest', id)).liked, isTrue);
  });

  testWidgets('둘러보기에는 공유된 문장만 작성자와 함께 나온다', (tester) async {
    await seedShared();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('기본'), findsNothing);
    expect(find.text('Hello there!'), findsNothing);
    await tester.scrollUntilVisible(find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('@Mina'), findsOneWidget);
  });

  testWidgets('공유된 문장이 없으면 안내한다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shared-message')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('아직 공유된 문장이 없어요'), findsOneWidget);
  });

  testWidgets('둘러보기 문장을 누르면 상세가 열리고 저장 전에는 루틴·공유 항목이 없다', (tester) async {
    await seedShared();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Could I get this to go?'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sentence-author')), findsOneWidget);
    expect(find.text('Mina'), findsWidgets);
    expect(find.byKey(const ValueKey('like-sentence')), findsOneWidget);
    expect(find.text('홈 말하기 루틴'), findsNothing);
    expect(find.byKey(const ValueKey('publish-sentence')), findsNothing);
  });

  testWidgets('내 문장 탭에서 기본 문장을 누르면 상세가 열린다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello there!'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('like-sentence')), findsOneWidget);
    expect(find.text('홈 말하기 루틴'), findsOneWidget);
    // 기본 문장은 내가 등록한 문장이 아니라 공유할 수 없고, 이유를 알려준다.
    expect(find.byKey(const ValueKey('publish-sentence')), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('publish-sentence-disabled')));
    expect(find.textContaining('기본 문장은 공유할 수 없어요'), findsOneWidget);
  });
}
