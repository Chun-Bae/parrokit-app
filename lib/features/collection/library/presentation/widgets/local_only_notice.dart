// 무료 사용자의 보관함 맨 위 안내(5차 5단계).
//
// 구독하지 않으면 클립이 이 기기에만 있다. 폰을 바꾸거나 앱을 지우면
// 사라지는데, 전에는 그 사실을 어디에서도 알리지 않았다.
// 겁주지 않고 할 수 있는 일(백업 파일 만들기)을 함께 둔다.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

const String localOnlyNoticeTitle = '이 기기에만 있어요';
const String localOnlyDismissTooltip = '오늘은 그만 보기';
const String localOnlyBackupLabel = '백업 파일 만들기';
const String localOnlySubscribeLabel = '구독 보기';

/// 몇 개가 사라지는지 적는다. 예전에는 '클립이 사라져요'라고만 해서, 서버에
/// 올라간 클립이 섞여 있어도 전부 사라지는 것처럼 읽혔다(5차).
///
/// 이 수는 보관함 전체를 센다(5차 484). 폴더 안에서도 같은 안내가 뜨는데
/// 거기서는 '이 폴더의 클립 3개' 바로 아래에 '클립 5개가 사라져요'가 붙어
/// 어느 쪽이 맞는지 알 수 없었다. 백업은 폴더가 아니라 보관함 전체를
/// 담으므로 수는 그대로 두고, 무엇을 센 수인지 적는다.
String localOnlyNoticeBody(int localOnlyCount) =>
    '폰을 바꾸면 보관함의 클립 $localOnlyCount개가 사라져요. '
    '백업 파일을 만들어 두면 다시 불러올 수 있어요.';

/// 구독하면 서버에 자동으로 올라가므로 이 안내를 보여 주지 않는다.
/// 이 기기에만 있는 클립이 없으면(예전 구독으로 서버에 다 올라가 있으면)
/// 알릴 것도 없다.
bool showsLocalOnlyNotice({
  required SubscriptionTier tier,
  required int localOnlyCount,
}) =>
    tier == SubscriptionTier.free && localOnlyCount > 0;

/// 오늘 이 안내를 닫았는지 적어 두는 곳(5차 565, 사용자 요청).
///
/// 알리지 않으면 폰을 바꿀 때 클립이 사라지는 줄 모른다. 그렇다고 보관함을
/// 열 때마다 같은 띠가 버티고 있으면 성가시다. 닫으면 그날은 쉬고 다음 날
/// 다시 한 번 알린다.
class LocalOnlyNoticeDismissal {
  LocalOnlyNoticeDismissal._();

  static const String key = 'parrokit.local_only_notice.dismissed_on.v1';

  /// 날은 한국 자정으로 가른다. 앱의 다른 하루치(한도·연습)와 같은 기준이다.
  static String dayOf(DateTime now) {
    final kst = now.toUtc().add(const Duration(hours: 9));
    return '${kst.year}-${kst.month}-${kst.day}';
  }

  static Future<bool> dismissedToday({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) == dayOf(now ?? DateTime.now());
    } catch (_) {
      // 못 읽으면 보여 준다. 안 보여 주는 쪽이 더 나쁘다.
      return false;
    }
  }

  static Future<void> dismissToday({DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, dayOf(now ?? DateTime.now()));
    } catch (_) {
      // 못 적으면 다음에 또 보일 뿐이다.
    }
  }
}

class LocalOnlyNotice extends StatefulWidget {
  const LocalOnlyNotice({
    super.key,
    required this.tier,
    required this.localOnlyCount,
    required this.onBackup,
    required this.onSubscribe,
  });

  final SubscriptionTier tier;

  /// 이 기기에만 있는 클립 수. 서버에 올라간 것은 세지 않는다.
  final int localOnlyCount;
  final VoidCallback onBackup;
  final VoidCallback onSubscribe;

  @override
  State<LocalOnlyNotice> createState() => _LocalOnlyNoticeState();
}

class _LocalOnlyNoticeState extends State<LocalOnlyNotice> {
  /// 오늘 닫았는지. 아직 모르면 null - 그동안은 그리지 않는다. 띄웠다가
  /// 곧바로 지우면 깜빡인다.
  bool? _dismissed;

  @override
  void initState() {
    super.initState();
    LocalOnlyNoticeDismissal.dismissedToday().then((hidden) {
      if (mounted) setState(() => _dismissed = hidden);
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    await LocalOnlyNoticeDismissal.dismissToday();
  }

  @override
  Widget build(BuildContext context) {
    if (!showsLocalOnlyNotice(
        tier: widget.tier, localOnlyCount: widget.localOnlyCount)) {
      return const SizedBox.shrink();
    }
    if (_dismissed ?? true) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        key: const ValueKey('local-only-notice'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          // 테두리를 걷고 면으로만 그린다(5차 565, 사용자 요청). 선 하나로
          // 두른 상자는 폼 칸처럼 보였다.
          color: cs.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘을 동그란 면에 올려 제목 줄에서 떼어 낸다.
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_iphone_rounded,
                  size: 20, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(localOnlyNoticeTitle,
                            style: context.texts.labelLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface)),
                      ),
                      // 닫으면 오늘은 쉰다. 다음 날 한 번 더 알린다.
                      IconButton(
                        key: const ValueKey('local-only-dismiss'),
                        tooltip: localOnlyDismissTooltip,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _dismiss,
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(localOnlyNoticeBody(widget.localOnlyCount),
                      style: context.texts.bodySmall
                          .copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 10),
                  // 할 수 있는 일을 앞세우고, 구독은 한 단 낮춘다. 전에는
                  // 둘이 같은 너비·같은 무게라 무엇을 먼저 할지 몰랐다.
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        key: const ValueKey('local-only-backup'),
                        onPressed: widget.onBackup,
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(localOnlyBackupLabel),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        key: const ValueKey('local-only-subscribe'),
                        onPressed: widget.onSubscribe,
                        child: const Text(localOnlySubscribeLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
