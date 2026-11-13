import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/community/activity/domain/entities/activity_item.dart';
import 'package:parrokit/features/community/activity/presentation/widgets/activity_card.dart';

void main() {
  for (final (type, label) in [
    ('board', '게시판'),
    ('question', '질문'),
    ('vote', '투표'),
  ]) {
    testWidgets('활동 카드의 $type 글은 탭 이름 "$label" 칩을 단다', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ActivityCard(
            item: ActivityItem(
              id: 'a1',
              sourcePostId: 'p1',
              title: '제목',
              content: '내용',
              createdAt: DateTime(2026, 11, 13),
              boardType: type,
              activityType: 'written',
            ),
          ),
        ),
      ));
      expect(find.text(label), findsOneWidget);
      expect(find.text('일반'), findsNothing);
    });
  }
}
