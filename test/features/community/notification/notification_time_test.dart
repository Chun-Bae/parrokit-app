// 알림 목록 시각이 글·댓글과 같은 모양인지(5차).
//
// 전에는 알림 타일이 따로 셈해서, 글은 기기 시간대로 바꿔 적는데(toLocal)
// 알림만 그대로 적었다. 시각이 UTC로 오면 날짜가 하루 어긋날 수 있었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/notification/domain/entities/community_notification_item.dart';
import 'package:parrokit/features/community/notification/presentation/widgets/community_notification_tile.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';

CommunityNotificationItem _item(DateTime createdAt) =>
    CommunityNotificationItem(
      id: 'n1',
      recipientUserId: 'me',
      notificationType: 'comment',
      boardType: 'board',
      postId: 'p1',
      actorId: 'other',
      actorDisplayName: '봄배',
      title: '게시판에 새 댓글이 달렸어요.',
      body: '봄배님이 게시판에 댓글을 남겼어요.',
      isRead: false,
      createdAt: createdAt,
    );

void main() {
  testWidgets('알림 시각은 글·댓글과 같은 함수가 낸 글을 쓴다', (tester) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final createdAt = DateTime.now().subtract(const Duration(hours: 3));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityNotificationTile(
          item: _item(createdAt),
          onTap: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.text(formatCommunityTimeAgo(createdAt)), findsOneWidget);
  });

  testWidgets('UTC로 온 시각도 기기 시간대 날짜로 적는다', (tester) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // 일주일이 넘어 날짜로 적는 경우.
    final utc = DateTime.utc(2026, 1, 2, 23, 30);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityNotificationTile(item: _item(utc), onTap: () {}),
      ),
    ));
    await tester.pump();

    final local = utc.toLocal();
    expect(
        find.textContaining('${local.month}월 ${local.day}일'), findsOneWidget);
  });
}
