// 커뮤니티 시각 표시(5차): 일주일이 넘으면 날짜로.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12);
  String at(Duration ago) => formatCommunityTimeAgo(now.subtract(ago), now: now);

  test('일주일 안은 지난 시간으로', () {
    expect(formatCommunityTimeAgo(null), '');
    expect(at(const Duration(seconds: 20)), '방금 전');
    expect(at(const Duration(minutes: 5)), '5분 전');
    expect(at(const Duration(hours: 3)), '3시간 전');
    expect(at(const Duration(days: 6)), '6일 전');
  });

  test('일주일이 넘으면 날짜, 올해가 아니면 연도까지', () {
    expect(at(const Duration(days: 7)), '11월 7일');
    expect(formatCommunityTimeAgo(DateTime(2025, 3, 2), now: now),
        '2025년 3월 2일');
  });
}
