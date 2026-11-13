import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/swipe_action_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sentence_seed.dart';

late FakeFirebaseFirestore firestore;
late FirestoreSharedSentenceRepository repo;

Widget app() => MaterialApp(
    home: Scaffold(body: SentenceCollectionPreview(repository: repo)));

/// 둘러보기 전용 화면. 공유 문장 목록과 저장·좋아요 버튼이 여기 있다.
Widget exploreApp() => MaterialApp(
    home: Scaffold(
        body: SentenceCollectionPreview(repository: repo, exploreOnly: true)));

/// 다른 사람이 공유한 문장 하나를 서버에 넣어 둔다.
Future<void> seedShared() => seedSentence(
      firestore,
      'my-seed',
      ownerId: 'mina',
      authorName: 'Mina',
      text: 'Could I get this to go?',
      translation: '이거 포장해 주실 수 있나요?',
      topic: '카페',
      visibility: 'public',
    );

/// 내 문장 탭에서 주소 가져오기 창을 열고 주소를 입력해 확인까지 누른다.
Future<void> startUrlImport(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('내 문장'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('가져오기·내보내기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CSV·엑셀에서 가져오기'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('url-import-input')),
      'https://example.com/sentences.csv');
  await tester.tap(find.byKey(const ValueKey('url-import-confirm')));
}

Widget urlApp(String csv, {Future<Uint8List> Function(Uri)? fetcher}) =>
    MaterialApp(
        home: Scaffold(
            body: SentenceCollectionPreview(
      repository: repo,
      urlFetcher:
          fetcher ?? (uri) async => Uint8List.fromList(utf8.encode(csv)),
    )));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
    repo = FirestoreSharedSentenceRepository(firestore: firestore);
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

  testWidgets('저장한 공유 문장은 카드에 내 문장 표시가 붙는다', (tester) async {
    await seedShared();
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('saved-chip')), findsNothing);
    await tester.ensureVisible(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-chip'), skipOffstage: false),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('sentence-card-saved'), skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('공개가 취소되면 둘러보기 목록에서 바로 사라진다', (tester) async {
    await seedShared();
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    expect(find.text('Could I get this to go?', skipOffstage: false),
        findsOneWidget);
    await repo.unpublish(sentenceId: 'my-seed');
    await tester.pumpAndSettle();
    expect(find.text('Could I get this to go?', skipOffstage: false),
        findsNothing);
  });

  testWidgets('새로고침 버튼으로 새로 공유된 문장을 불러온다', (tester) async {
    await seedShared();
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    await seedSentence(firestore, 'my-new',
        ownerId: 'kai',
        authorName: 'Kai',
        text: 'Brand new shared line',
        topic: '일상',
        visibility: 'public');
    expect(
        find.text('Brand new shared line', skipOffstage: false), findsNothing);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('refresh-shared')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('refresh-shared')));
    await tester.pumpAndSettle();
    expect(find.text('Brand new shared line', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('둘러보기에서 저장한 문장이 내 문장에 나타난다', (tester) async {
    await seedShared();
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).length, 1);

    // 내 문장은 보관함 문장 탭에 있다.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Could I get this to go?', skipOffstage: false),
        findsWidgets);
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
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('기본'), findsNothing);
    expect(find.text('Hello there!'), findsNothing);
    await tester.scrollUntilVisible(find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('@Mina'), findsOneWidget);
  });

  testWidgets('공유된 문장이 없으면 안내한다', (tester) async {
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shared-message')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('아직 공유된 문장이 없어요'), findsOneWidget);
  });

  testWidgets('둘러보기 문장을 누르면 상세가 열리고 저장 전에는 루틴·공유 항목이 없다', (tester) async {
    await seedShared();
    await tester.pumpWidget(exploreApp());
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
    // 저장하지 않은 남의 문장에는 내 친밀도·들은 횟수·연습 기록이 보이지 않는다.
    expect(find.byKey(const ValueKey('private-section')), findsNothing);
    expect(find.byKey(const ValueKey('sentence-affinity')), findsNothing);
    expect(find.text('듣기'), findsNothing);
    expect(find.text('따라 말하기'), findsNothing);
    // 대신 내 문장으로 가져오는 버튼이 보이고, 누르면 저장된다.
    expect(find.byKey(const ValueKey('save-shared-sentence')), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const ValueKey('save-shared-sentence')));
    await tester.tap(find.byKey(const ValueKey('save-shared-sentence')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-shared-sentence')), findsNothing);
    final saved = await MySentenceStore.load('guest');
    expect(saved.any((s) => s.text == 'Could I get this to go?'), isTrue);
  });

  testWidgets('문장 상세에서 단어를 골라 저장하면 그 문장이 예문으로 붙는다', (tester) async {
    MyWordStore.cloud = null;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello there!'));
    await tester.pumpAndSettle();
    final chip = find.byKey(const ValueKey('pick-word-Hello'));
    await tester.ensureVisible(chip);
    expect(find.byKey(const ValueKey('pick-word-there')), findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('word-example-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('save-word')));
    await tester.pumpAndSettle();
    final saved = (await MyWordStore.load('guest')).single;
    expect(saved.word, 'Hello');
    expect(saved.example, 'Hello there!');
    expect(saved.sourceSentenceId, isNotEmpty);
    expect(find.text('단어를 저장했어요.'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('private-section')), findsOneWidget);
    expect(find.text('듣기'), findsOneWidget);
    // 기본 문장은 내가 등록한 문장이 아니라 공유할 수 없고, 이유를 알려준다.
    expect(find.byKey(const ValueKey('publish-sentence')), findsNothing);
    await tester
        .ensureVisible(find.byKey(const ValueKey('publish-sentence-disabled')));
    expect(find.textContaining('기본 문장은 공유할 수 없어요'), findsOneWidget);
  });

  testWidgets('친밀도 최고 단계 문장 카드만 금색 테두리가 된다', (tester) async {
    for (var i = 0; i < 25; i++) {
      await SentenceActivityStore.incrementPractice('guest', 'basic-en-001');
    }
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sentence-card-gold')), findsOneWidget);
    expect(find.text('Lv.5 능숙한'), findsOneWidget);
  });

  testWidgets('스크립트를 붙여넣어 문장으로 나누고 고른 문장만 추가한다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('가져오기·내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('스크립트 붙여넣어 문장 만들기'));
    await tester.pumpAndSettle();
    // 자동으로 가져오지 않는다는 고지가 보인다.
    expect(find.byKey(const ValueKey('script-notice')), findsOneWidget);
    expect(find.textContaining('자동으로 가져오지는 않아요'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('script-input')),
        '0:01\nNice to meet you!\n0:03\nWhere is the station?');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('script-split')));
    await tester.pumpAndSettle();
    expect(find.text('Nice to meet you!'), findsOneWidget);
    expect(find.text('Where is the station?'), findsOneWidget);
    await tester.tap(find.text('Where is the station?'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('script-add')));
    await tester.pumpAndSettle();
    expect(find.text('Nice to meet you!', skipOffstage: false), findsOneWidget);
    expect(
        find.text('Where is the station?', skipOffstage: false), findsNothing);
  });

  testWidgets('주소에서 받은 문장을 목록으로 보여주고 고른 문장만 가져온다', (tester) async {
    Uri? requested;
    await tester.pumpWidget(urlApp('', fetcher: (uri) async {
      requested = uri;
      return Uint8List.fromList(
          utf8.encode('문장,뜻\nSee you soon,곧 봐요\nHello,안녕\nTake care,몸조심해요\n'));
    }));
    await startUrlImport(tester);
    await tester.pumpAndSettle();

    expect(requested, Uri.parse('https://example.com/sentences.csv'));
    // 아직 등록되지 않고 목록에서 고른다.
    expect(find.byKey(const ValueKey('import-sheet')), findsOneWidget);
    expect(find.text('가져올 문장 3개'), findsOneWidget);
    expect(find.text('3개 가져오기'), findsOneWidget);
    expect((await MySentenceStore.load('guest')), isEmpty);

    // 하나를 빼면 2개만 가져온다.
    await tester.tap(find.byKey(const ValueKey('import-item-1')));
    await tester.pump();
    expect(find.text('2개 가져오기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-summary')), findsOneWidget);
    expect(find.text('2개를 가져왔어요.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-done')));
    await tester.pumpAndSettle();

    final saved = (await MySentenceStore.load('guest')).map((e) => e.text);
    expect(saved, containsAll(['See you soon', 'Take care']));
    expect(saved, isNot(contains('Hello')));
    expect(find.textContaining('2개를 가져왔어요'), findsOneWidget);
  });

  testWidgets('옮기기가 끝난 뒤 취소하면 방금 가져온 문장이 모두 사라진다', (tester) async {
    await tester
        .pumpWidget(urlApp('문장,뜻\nSee you soon,곧 봐요\nTake care,몸조심해요\n'));
    await startUrlImport(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-start')));
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).length, 2);

    await tester.tap(find.byKey(const ValueKey('import-undo')));
    await tester.pumpAndSettle();
    expect(await MySentenceStore.load('guest'), isEmpty);
    // 닫히지 않고 고르는 목록으로 돌아가서 URL이나 파일을 다시 고르지 않아도 된다.
    expect(find.byKey(const ValueKey('import-sheet')), findsOneWidget);
    expect(find.text('2개 가져오기'), findsOneWidget);

    // 하나만 빼고 다시 가져온다.
    await tester.tap(find.byKey(const ValueKey('import-item-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('import-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-done')));
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).map((e) => e.text),
        ['See you soon']);
  });

  testWidgets('이미 있는 문장은 목록에서 제외되고 가져오기 전에 취소할 수 있다', (tester) async {
    await MySentenceStore.add('guest', language: '영어', text: 'See you soon');
    await tester
        .pumpWidget(urlApp('문장,뜻\nSee you soon,곧 봐요\nTake care,몸조심해요\n'));
    await startUrlImport(tester);
    await tester.pumpAndSettle();
    expect(find.text('1개 가져오기'), findsOneWidget);
    expect(find.textContaining('이미 있어요'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('import-cancel')));
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).length, 1);
  });

  testWidgets('주소에서 가져오는 동안 진행 창이 보이고 끝나면 닫힌다', (tester) async {
    final download = Completer<Uint8List>();
    await tester.pumpWidget(urlApp('', fetcher: (uri) => download.future));
    await startUrlImport(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('import-progress')), findsOneWidget);
    expect(find.textContaining('파일을 받는 중'), findsOneWidget);

    download
        .complete(Uint8List.fromList(utf8.encode('문장,뜻\nSee you soon,곧 봐요\n')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-progress')), findsNothing);
    expect(find.byKey(const ValueKey('import-sheet')), findsOneWidget);
  });

  testWidgets('중첩된 내비게이터 안에서 가져와도 진행 창만 닫히고 화면은 남는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => SentenceCollectionPreview(
                repository: repo,
                urlFetcher: (uri) async => Uint8List.fromList(
                    utf8.encode('문장,뜻\nSee you soon,곧 봐요\n')),
              )),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('가져오기·내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV·엑셀에서 가져오기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('url-import-input')),
        'https://example.com/sentences.csv');
    await tester.tap(find.byKey(const ValueKey('url-import-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-progress')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('import-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-done')));
    await tester.pumpAndSettle();
    expect(find.byType(SentenceCollectionPreview), findsOneWidget);
    expect(find.text('See you soon', skipOffstage: false), findsOneWidget);
  });

  testWidgets('https가 아닌 주소는 내려받지 않고 안내한다', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SentenceCollectionPreview(
      repository: repo,
      urlFetcher: (uri) async {
        called = true;
        return Uint8List(0);
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('가져오기·내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV·엑셀에서 가져오기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('url-import-input')),
        'http://example.com/a.csv');
    await tester.tap(find.byKey(const ValueKey('url-import-confirm')));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.textContaining('https로 시작하는 주소만'), findsOneWidget);
  });

  testWidgets('문장 상세에서 메모를 쓰면 저장되고 다시 열면 보인다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello there!'));
    await tester.pumpAndSettle();
    final memo = find.byKey(const ValueKey('sentence-memo'));
    await tester.ensureVisible(memo);
    await tester.enterText(memo, '  인사할 때 쓰기  ');
    await tester.pump(const Duration(seconds: 1));
    final saved = await SentenceActivityStore.load('guest', 'basic-en-001');
    expect(saved.memo, '인사할 때 쓰기');
    // 지우면 메모도 사라진다.
    await tester.enterText(memo, '');
    await tester.pump(const Duration(seconds: 1));
    expect(
        (await SentenceActivityStore.load('guest', 'basic-en-001')).memo, '');
  });
  testWidgets('메모는 다른 활동 기록을 지우지 않는다', (tester) async {
    await SentenceActivityStore.incrementPractice('guest', 'basic-en-001');
    await SentenceActivityStore.setMemo('guest', 'basic-en-001', '메모');
    final activity = await SentenceActivityStore.load('guest', 'basic-en-001');
    expect(activity.memo, '메모');
    expect(activity.practiceCount, 1);
  });

  test('가져간 사람 수는 사람마다 한 번만 올라가고 원작자는 세지 않는다', () async {
    await seedShared();
    Future<int> count() async =>
        ((await firestore.collection('sentences').doc('my-seed').get())
                .data()!['importCount'] as num)
            .toInt();
    expect(
        await repo.recordImport(sharedId: 'my-seed', viewerId: 'u2'), isTrue);
    expect(await count(), 1);
    // 같은 사람이 다시 가져가도 늘지 않는다.
    expect(
        await repo.recordImport(sharedId: 'my-seed', viewerId: 'u2'), isFalse);
    expect(await count(), 1);
    expect(
        await repo.recordImport(sharedId: 'my-seed', viewerId: 'u3'), isTrue);
    expect(await count(), 2);
    // 원작자 본인은 세지 않는다.
    expect(await repo.recordImport(sharedId: 'my-seed', viewerId: 'mina'),
        isFalse);
    expect(await count(), 2);
    // 없는 문장은 세지 않는다.
    expect(await repo.recordImport(sharedId: 'nope', viewerId: 'u2'), isFalse);
  });

  testWidgets('둘러보기 카드에 가져간 사람 수가 보인다', (tester) async {
    await seedSentence(
      firestore,
      'my-popular',
      ownerId: 'mina',
      authorName: 'Mina',
      text: 'See you around!',
      translation: '또 봐요!',
      visibility: 'public',
      importCount: 7,
    );
    await tester.pumpWidget(exploreApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('See you around!'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('shared-import-count')), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('문장 탭은 둘러보기 한 줄과 내 문장을 함께 보여준다', (tester) async {
    await seedShared();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // 둘러보기 한 줄에 공유 문장이 보이고, 전체 버튼이 있다.
    expect(find.text('Could I get this to go?'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-explore')), findsOneWidget);
    // 예전 "내 문장 / 둘러보기" 전환과 앵무새 배너는 없다.
    expect(find.text('앵무새가 말할 문장'), findsNothing);
    await tester.scrollUntilVisible(find.text('Hello there!'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Hello there!'), findsOneWidget);
  });

  /// 이 문장 줄 안의 동작 버튼. 동작 칸은 모든 줄 뒤에 깔려 있어서 줄로 좁힌다.
  Finder rowAction(String sentence, String label) => find.descendant(
      of: find.ancestor(
          of: find.text(sentence), matching: find.byType(SwipeActionTile)),
      matching: find.text(label));

  testWidgets('내 문장을 밀면 앵무새 끄기와 삭제를 할 수 있다', (tester) async {
    await MySentenceStore.add('guest',
        language: '영어', text: 'Swipe me', translation: '밀어 봐');
    final id = MySentenceStore.idFor('영어', 'Swipe me');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Swipe me'), 300,
        scrollable: find.byType(Scrollable).first);

    await tester.drag(find.text('Swipe me'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(rowAction('Swipe me', '앵무새 끄기'));
    await tester.pumpAndSettle();
    expect((await SentenceActivityStore.load('guest', id)).routineEnabled,
        isFalse);

    await tester.drag(find.text('Swipe me'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(rowAction('Swipe me', '앵무새 켜기'), findsOneWidget);
    await tester.tap(rowAction('Swipe me', '삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).any((s) => s.id == id),
        isFalse);
  });

  testWidgets('기본 문장은 밀어도 삭제가 없다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hello there!'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.text('Hello there!'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(rowAction('Hello there!', '앵무새 끄기'), findsOneWidget);
    expect(rowAction('Hello there!', '삭제'), findsNothing);
  });
}
