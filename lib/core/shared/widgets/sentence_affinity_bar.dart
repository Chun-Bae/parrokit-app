import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 단계별 뱃지(`assets/badges/affinity_N.svg`)와 같은 계열의 칩 배경색과 글자색.
(Color, Color) affinityChipColors(int level) {
  const palette = [
    (Color(0xFFCFD8DC), Color(0xFF455A64)),
    (Color(0xFFC5E8B7), Color(0xFF2E6F3C)),
    (Color(0xFFA8F0E6), Color(0xFF0B6B66)),
    (Color(0xFFB9C8FF), Color(0xFF2E32A8)),
    (Color(0xFFFFE7A0), Color(0xFF8A4B00)),
    // Lv.6·7은 5차 566에서 얹었다. 뱃지 그림은 아직 5개라 칩 색만 는다.
    (Color(0xFFFFD1B3), Color(0xFF8A3A00)),
    (Color(0xFFE6C9FF), Color(0xFF5B2E8A)),
  ];
  return palette[(level - 1).clamp(0, palette.length - 1)];
}

/// 막대 아래 안내 한 줄.
///
/// [activity]를 주면 **오늘 남은 몫**을 함께 말한다. 몫을 다 쓴 뒤에도
/// '들으면 1점'이라고 적어 두면, 열 번을 더 들어도 막대가 안 움직이니
/// 고장난 것으로 보인다(5차 566).
String affinityHint(
  SentenceAffinity affinity, {
  SentenceActivity? activity,
  DateTime? now,
}) {
  if (affinity.isMax) return '최고 단계예요';
  final remaining = affinity.next! - affinity.points;
  const ways = '들으면 1점, 따라 말하면 1~3점';
  if (activity == null) return '다음 단계까지 $remaining점 · $ways';
  final at = now ?? DateTime.now();
  if (sentenceRoomToday(activity, now: at) == 0) {
    return '$sentenceDayFullMessage · 내일 다시 쌓여요';
  }
  if (sentenceListenRoomToday(activity, now: at) == 0) {
    return '다음 단계까지 $remaining점 · 오늘 듣기 몫은 다 썼어요, 따라 말하면 1~3점';
  }
  return '다음 단계까지 $remaining점 · $ways';
}

/// 문장 친밀도 단계와 다음 단계까지 진행 막대. 상세 시트와 따라 말하기 화면에서 함께 쓴다.
/// [compact]면 안내 문구 없이 한 줄과 얇은 막대만 그린다.
class SentenceAffinityBar extends StatelessWidget {
  const SentenceAffinityBar({
    super.key,
    required this.affinity,
    this.loading = false,
    this.compact = false,
    this.activity,
  });

  final SentenceAffinity affinity;

  /// 이 문장의 오늘 기록. 주면 남은 몫을 안내에 함께 적는다.
  final SentenceActivity? activity;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final remaining = affinity.isMax ? 0 : affinity.next! - affinity.points;
    final title = loading
        ? '친밀도'
        : compact
            ? 'Lv.${affinity.level} ${affinity.name}'
            : '친밀도 Lv.${affinity.level} · ${affinity.name}';
    final hint = affinityHint(affinity, activity: activity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SvgPicture.asset(
              'assets/badges/affinity_${affinity.badgeLevel}.svg',
              width: compact ? 20 : 28,
              height: compact ? 20 : 28),
          SizedBox(width: compact ? 6 : 8),
          Text(title,
              style: compact
                  ? context.texts.bodySmall
                      .copyWith(fontWeight: FontWeight.w800)
                  : context.texts.bodyMedium
                      .copyWith(fontWeight: FontWeight.w800)),
          if (compact && !loading) ...[
            const Spacer(),
            // 무엇이 몇 점 남았는지 말한다(5차). 예전 '3점 남음'·'MAX'로는
            // 무슨 점수인지 알 수 없었다(아래 설명 줄은 compact에서 숨는다).
            Text(affinity.isMax ? '최고 단계' : '다음 단계까지 $remaining점',
                style: context.texts.labelSmall
                    .copyWith(color: colors.onSurfaceVariant)),
          ],
        ]),
        SizedBox(height: compact ? 6 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: loading ? 0 : affinity.progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: compact ? 5 : 6,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(hint,
              style: context.texts.labelSmall
                  .copyWith(color: colors.onSurfaceVariant)),
        ],
      ],
    );
  }
}
