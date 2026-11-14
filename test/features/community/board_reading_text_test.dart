// 긴 글은 제목보다 가볍게 보여야 한다(5차).
//
// 앱 타이포 스케일은 모든 역할이 굵어서(w600~w900), 게시글 본문이 제목과
// 같은 w800으로 그려졌다. 글 전체가 제목처럼 보이고 제목·본문 구분이
// 크기 2pt뿐이었다. 읽는 글 전용 굵기를 따로 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_post_content_section.dart';

Post _post() => Post(
      id: 'p1',
      postType: 'board',
      category: '자유',
      title: '안녕하세요',
      content: '잘 부탁드립니다.\n여러 줄을 이어 읽는 글이에요.',
      authorId: 'u1',
      authorNickname: 'ch',
      snippet: '잘 부탁드립니다.',
      createdAt: DateTime(2026, 8, 4),
    );

void main() {
  test('읽는 글 굵기는 보통이고 다른 역할은 그대로 굵다', () {
    expect(AppTextScale.bodyReading.fontWeight, FontWeight.w400);
    expect(AppTextScale.titleLarge.fontWeight, FontWeight.w800);
  });

  testWidgets('게시글 본문은 제목보다 가볍게 그린다', (tester) async {
    final post = _post();
    final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
    await tester.pumpWidget(MaterialApp(
      // 앱이 쓰는 글자 테마로 그려야 실제 굵기가 나온다.
      theme: ThemeData(
        colorScheme: cs,
        textTheme: appTextTheme(cs, isDark: false),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BoardPostContentSection(post: post),
        ),
      ),
    ));

    final title = tester.widget<Text>(find.text(post.title));
    final body = tester.widget<Text>(find.text(post.content));
    expect(body.style!.fontWeight, FontWeight.w400);
    expect(
      title.style!.fontWeight!.index,
      greaterThan(body.style!.fontWeight!.index),
      reason: '제목이 본문보다 굵어야 글의 머리가 보인다',
    );
  });
}
