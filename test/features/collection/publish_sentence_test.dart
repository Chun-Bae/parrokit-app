import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

const mine = DefaultConversationSentence(
  id: 'my-영어-1',
  language: '영어',
  text: 'My own sentence',
  translation: '내 문장',
  pronunciation: '',
  topic: '내 문장',
);

late FirestoreSharedSentenceRepository repo;

Future<void> openSheet(
  WidgetTester tester, {
  String accountId = 'u1',
  String authorName = '앵무',
  DefaultConversationSentence sentence = mine,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showSentenceDetails(
            context,
            sentence: sentence,
            accountId: accountId,
            repository: repo,
            authorName: authorName,
          ),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo =
        FirestoreSharedSentenceRepository(firestore: FakeFirebaseFirestore());
  });

  testWidgets('확인 후 공유하면 작성자와 함께 올라가고 다시 누르면 취소된다', (tester) async {
    await openSheet(tester);
    expect(find.text('둘러보기에 공유하기'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('publish-sentence')));
    await tester.tap(find.byKey(const ValueKey('publish-sentence')));
    await tester.pumpAndSettle();
    expect(find.text('둘러보기에 공유할까요?'), findsOneWidget);
    expect(find.textContaining('"앵무"'), findsOneWidget);
    await tester.tap(find.text('공유'));
    await tester.pumpAndSettle();

    final list = await repo.list(language: '영어', viewerId: 'u1');
    expect(list.single.text, 'My own sentence');
    expect(list.single.authorId, 'u1');
    expect(list.single.authorName, '앵무');
    expect(find.text('둘러보기 공유 취소'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('publish-sentence')));
    await tester.pumpAndSettle();
    expect(await repo.list(language: '영어', viewerId: 'u1'), isEmpty);
    expect(find.text('둘러보기에 공유하기'), findsOneWidget);
  });

  testWidgets('확인에서 취소하면 올라가지 않는다', (tester) async {
    await openSheet(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('publish-sentence')));
    await tester.tap(find.byKey(const ValueKey('publish-sentence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await repo.list(language: '영어', viewerId: 'u1'), isEmpty);
  });

  testWidgets('이미 공유된 문장은 공유 취소로 시작한다', (tester) async {
    await repo.publish(
      localSentenceId: mine.id,
      authorId: 'u1',
      authorName: '앵무',
      language: '영어',
      text: mine.text,
      translation: mine.translation,
      pronunciation: '',
      topic: '내 문장',
    );
    await openSheet(tester);
    expect(find.text('둘러보기 공유 취소'), findsOneWidget);
  });

  testWidgets('로그인하지 않았거나 닉네임이 없으면 공유하지 않고 안내한다', (tester) async {
    await openSheet(tester, accountId: 'guest');
    await tester.ensureVisible(find.byKey(const ValueKey('publish-sentence')));
    await tester.tap(find.byKey(const ValueKey('publish-sentence')));
    await tester.pumpAndSettle();
    expect(find.text('로그인 후 공유할 수 있어요.'), findsOneWidget);
    expect(find.text('둘러보기에 공유할까요?'), findsNothing);
  });

  testWidgets('닉네임이 비어 있으면 먼저 설정하라고 안내한다', (tester) async {
    await openSheet(tester, authorName: '');
    await tester.ensureVisible(find.byKey(const ValueKey('publish-sentence')));
    await tester.tap(find.byKey(const ValueKey('publish-sentence')));
    await tester.pumpAndSettle();
    expect(find.text('닉네임을 먼저 설정해주세요.'), findsOneWidget);
  });

  testWidgets('남의 문장을 저장한 사본에는 공유 버튼이 없다', (tester) async {
    await openSheet(
      tester,
      sentence: const DefaultConversationSentence(
        id: 'my-영어-2',
        language: '영어',
        text: 'Copied',
        translation: '복사',
        pronunciation: '',
        topic: '카페',
        author: 'Mina',
      ),
    );
    expect(find.byKey(const ValueKey('publish-sentence')), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('publish-sentence-disabled')));
    expect(find.textContaining('다른 사람이 만든 문장은 공유할 수 없어요'), findsOneWidget);
  });

  testWidgets('공개 문장의 좋아요는 서버 저장 콜백을 부르고 실패하면 되돌린다', (tester) async {
    final calls = <bool>[];
    var fail = false;
    const shared = SharedSentence(
      id: 'mina:my-1',
      language: '영어',
      text: 'Shared one',
      translation: '공유',
      pronunciation: '',
      topic: '카페',
      authorId: 'mina',
      authorName: 'Mina',
      likeCount: 5,
    );
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showSentenceDetails(
              context,
              accountId: 'u1',
              shared: shared,
              onSharedLike: (liked) async {
                calls.add(liked);
                if (fail) throw StateError('fail');
              },
              sentence: const DefaultConversationSentence(
                id: 'my-영어-3',
                language: '영어',
                text: 'Shared one',
                translation: '공유',
                pronunciation: '',
                topic: '카페',
                author: 'Mina',
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('like-sentence')));
    await tester.pumpAndSettle();
    expect(calls, [true]);
    expect(find.text('6'), findsOneWidget);

    fail = true;
    await tester.tap(find.byKey(const ValueKey('like-sentence')));
    await tester.pumpAndSettle();
    expect(calls, [true, false]);
    expect(find.text('6'), findsOneWidget);
  });
}
