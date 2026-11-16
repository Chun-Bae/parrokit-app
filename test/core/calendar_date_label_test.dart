// 오래된 시각을 날짜로 적는 규칙. 올해가 아니면 연도까지 붙인다(5차).
// 같은 규칙을 세 곳이 따로 적어 두고 있었고, 홈 둘러보기 카드만 연도를
// 빼먹어 작년 글이 올해 글처럼 보였다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/utils/calendar_date_label.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

void main() {
  final now = DateTime(2026, 11, 16, 12);

  test('올해면 월·일만, 아니면 연도까지', () {
    expect(calendarDateLabel(DateTime(2026, 8, 4), now), '8월 4일');
    expect(calendarDateLabel(DateTime(2025, 8, 4), now), '2025년 8월 4일');
  });

  test('커뮤니티 글과 문장 친밀도도 같은 말을 쓴다', () {
    expect(formatCommunityTimeAgo(DateTime(2025, 8, 4), now: now),
        '2025년 8월 4일');
    expect(relativeDayLabel(now, DateTime(2025, 8, 4)), '2025년 8월 4일');
    // 일주일 안쪽은 그대로 '며칠 전'이다.
    expect(formatCommunityTimeAgo(now.subtract(const Duration(days: 3)),
            now: now),
        '3일 전');
    expect(relativeDayLabel(now, now.subtract(const Duration(days: 1))), '어제');
  });

  test('홈 둘러보기 카드도 같은 곳에서 가져다 쓴다', () {
    // 비공개 위젯이라 바로 부를 수 없어, 그 규칙을 쓰는지 코드로 확인한다.
    final code = File(
            'lib/features/home/dashboard/presentation/widgets/trending_sentences_preview.dart')
        .readAsStringSync();
    expect(code, contains('calendarDateLabel(at, now)'));
    expect(code.contains("return '\${at.month}월 \${at.day}일';"), isFalse);
  });

  test('구독 날짜도 같은 규칙을 쓴다', () {
    // 12월에 보는 다음 결제일 1월 5일은 내년이다.
    final december = DateTime(2026, 12, 20);
    expect(
      subscriptionRenewalLine(DateTime(2027, 1, 5), now: december),
      '다음 결제일 2027년 1월 5일',
    );
    expect(
      subscriptionStatusNotice(
          SubscriptionStatus.canceled, DateTime(2027, 1, 5),
          now: december),
      startsWith('2027년 1월 5일에'),
    );
    // 올해 안이면 그대로 월·일만.
    expect(subscriptionRenewalLine(DateTime(2026, 12, 15), now: december),
        '다음 결제일 12월 15일');
  });

  test('날짜를 손으로 조립하는 곳이 더 생기지 않게 한다', () {
    // 같은 규칙을 화면마다 따로 적다가 한쪽만 고쳐진 적이 여러 번 있었다
    // (자막 글꼴, 글 날짜, 숫자 이름, 서버 한도).
    const allowed = {
      'lib/core/shared/utils/calendar_date_label.dart',
      // 달력 칸 안이라 '2026년 11월' 머리말이 이미 위에 있다.
      'lib/features/home/dashboard/presentation/widgets/study_garden_preview.dart',
    };
    final pattern = RegExp(r'월 \$?\{?\w');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed.contains(entity.path)) continue;
      for (final line in entity.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        if (!line.contains('일')) continue;
        if (pattern.hasMatch(line)) offenders.add('${entity.path}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'calendarDateLabel을 쓰세요(올해가 아니면 연도까지):\n'
            '${offenders.join('\n')}');
  });
}
