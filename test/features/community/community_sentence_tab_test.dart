// 커뮤니티 네 탭(게시판·문장·질문·투표)과 문장 공유 길(5차 340·341).

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_share_text.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/share_my_sentence_sheet.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MySentenceStore.cloud = null;
  });

  test('커뮤니티 탭 차례는 게시판·문장·질문·투표', () {
    final code = File(
            'lib/features/community/shell/presentation/community_shell_screen.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('TabController(length: 4'));
    expect(
        code,
        contains(
            "Tab(text: '게시판'), // 공유된 문장 둘러보기가 여기로 들어왔다(5차 340, 사용자 요청). Tab(text: '문장'), Tab(text: '질문'), Tab(text: '투표'),"));
    // 거르는 줄은 셋만 알아서 차례를 맞춰 넘긴다.
    expect(code, contains('_tabController.index - 1'));
  });

  test('보관함·홈 전체 보기는 커뮤니티 문장 탭으로 간다', () {
    final code = File(
            'lib/features/collection/shell/presentation/open_shared_sentences.dart')
        .readAsStringSync();
    expect(code, contains('CommunityShellScreen.sentenceTab'));
    expect(code, contains('AppRoutes.communityPath'));
    expect(
        File('lib/features/collection/shell/presentation/sentence_explore_screen.dart')
            .existsSync(),
        isFalse,
        reason: '따로 띄우던 둘러보기 화면은 커뮤니티 탭으로 옮겼다');
  });

  test('공유를 묻는 말은 한 곳에서 온다', () {
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/share_my_sentence_sheet.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(code, contains('sentenceShareTitle('), reason: path);
      expect(code.contains("'공개되는 것: 문장, 뜻, 발음"), isFalse, reason: path);
    }
    expect(sentenceShareTitle(published: false), '둘러보기에 공유할까요?');
    expect(sentenceShareBody(published: false, authorName: '춘배'),
        contains('작성자 "춘배"'));
  });

  testWidgets('공유 시트는 내 문장을 언어와 함께 보여 주고 공유를 묻는다', (tester) async {
    await MySentenceStore.add('me',
        language: '영어', text: 'Nice to meet you.', translation: '만나서 반가워요.');
    final repo =
        FirestoreSharedSentenceRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShareMySentenceSheet(
          accountId: 'me',
          authorName: '춘배',
          repository: repo,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nice to meet you.'), findsOneWidget);
    expect(find.text('영어 · 만나서 반가워요.'), findsOneWidget);

    await tester.tap(find.text('공유'));
    await tester.pumpAndSettle();
    expect(find.text(sentenceShareTitle(published: false)), findsOneWidget);
  });

  testWidgets('닉네임이 없으면 공유를 막고 까닭을 알린다', (tester) async {
    await MySentenceStore.add('me', language: '영어', text: 'Hello there!');
    final repo =
        FirestoreSharedSentenceRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShareMySentenceSheet(
          accountId: 'me',
          authorName: '  ',
          repository: repo,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('공유'));
    await tester.pump();
    expect(find.text(sentenceShareNeedsNickname), findsOneWidget);
    expect(find.text(sentenceShareTitle(published: false)), findsNothing);
  });

  testWidgets('공유된 문장이 없으면 바로 공유할 수 있게 안내한다', (tester) async {
    final repo =
        FirestoreSharedSentenceRepository(firestore: FakeFirebaseFirestore());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SentenceCollectionPreview(repository: repo, exploreOnly: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('아직 공유된 문장이 없어요. 내 문장을 공유해 보세요.'), findsOneWidget);
    expect(find.text('내 문장 공유하기'), findsOneWidget);
    // 큰 제목은 커뮤니티 탭 이름과 겹쳐서 뺐다(5차 343).
    expect(find.text('공유된 문장'), findsNothing);
    expect(find.text('저장해서 내 문장으로 연습해요'), findsOneWidget);
  });
}
