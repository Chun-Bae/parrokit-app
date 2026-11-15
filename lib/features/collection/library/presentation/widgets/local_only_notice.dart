// 무료 사용자의 보관함 맨 위 안내(5차 5단계).
//
// 구독하지 않으면 클립이 이 기기에만 있다. 폰을 바꾸거나 앱을 지우면
// 사라지는데, 전에는 그 사실을 어디에서도 알리지 않았다.
// 겁주지 않고 할 수 있는 일(백업 파일 만들기)을 함께 둔다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

const String localOnlyNoticeTitle = '이 기기에만 있어요';
const String localOnlyNoticeBody =
    '폰을 바꾸면 클립이 사라져요. 백업 파일을 만들어 두면 다시 불러올 수 있어요.';
const String localOnlyBackupLabel = '백업 파일 만들기';
const String localOnlySubscribeLabel = '구독 보기';

/// 구독하면 서버에 자동으로 올라가므로 이 안내를 보여 주지 않는다.
/// 클립이 하나도 없는 사람에게도 보여 줄 일이 없다.
bool showsLocalOnlyNotice({
  required SubscriptionTier tier,
  required int clipCount,
}) =>
    tier == SubscriptionTier.free && clipCount > 0;

class LocalOnlyNotice extends StatelessWidget {
  const LocalOnlyNotice({
    super.key,
    required this.tier,
    required this.clipCount,
    required this.onBackup,
    required this.onSubscribe,
  });

  final SubscriptionTier tier;
  final int clipCount;
  final VoidCallback onBackup;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    if (!showsLocalOnlyNotice(tier: tier, clipCount: clipCount)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        key: const ValueKey('local-only-notice'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.phone_iphone_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text(localOnlyNoticeTitle,
                  style: context.texts.labelLarge.copyWith(
                      fontWeight: FontWeight.w800, color: cs.onSurface)),
            ]),
            const SizedBox(height: 6),
            Text(localOnlyNoticeBody,
                style: context.texts.bodySmall
                    .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton.tonal(
                  key: const ValueKey('local-only-backup'),
                  onPressed: onBackup,
                  child: const Text(localOnlyBackupLabel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('local-only-subscribe'),
                  onPressed: onSubscribe,
                  child: const Text(localOnlySubscribeLabel),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
