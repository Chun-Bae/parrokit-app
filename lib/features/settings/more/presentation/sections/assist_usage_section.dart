// 더보기의 '오늘 쓴 자동 채우기'. 지갑 카드 바로 아래에 둔다(사용자 요청).
//
// 패롯·크래커는 지갑 카드에서 잔액을 볼 수 있는데, 하루 한도는 볼 곳이
// 없었다. 단어나 문장 창을 열어야만 '오늘 2/3회 사용'이 보였고, 다 쓴 뒤에야
// 알게 됐다.
//
// 두 한도는 **서로 다른 축**이다. 뜻·발음 채우기와 예문 생성은 각자 세고
// 서로 깎지 않는다. 한 줄로 뭉뚱그리면 또 헷갈리므로 나눠 적는다(5차 531).

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/example_credits.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/reward_celebration.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

const String assistUsageSectionTitle = '오늘 쓴 자동 채우기';
const String assistUsageBasicsLabel = fillBasicsLabel;
const String assistUsageExamplesLabel = '예문 생성';

/// 'N / M번'처럼. 사 둔 몫이 있으면 같은 줄에 '+K'로 붙인다(5차 535).
///
/// 전에는 사 둔 몫을 줄 하나로 따로 뒀는데, 같은 한도를 두 줄로 쪼개 놓으니
/// 읽기 어려웠다(사용자 지적). 하루 한도는 날마다 리셋되고 사 둔 몫은 안
/// 사라지므로 수는 합치지 않고 괄호로 덧붙인다.
String assistUsageCount(int? used, int limit, String unit, [int credits = 0]) {
  final head = used == null ? '— / $limit$unit' : '$used / $limit$unit';
  return credits > 0 ? '$head +$credits' : head;
}

/// 내일 0시(KST)에 돌아온다는 안내. 두 한도가 같은 때에 돌아온다.
const String assistUsageResetHint = '한도는 날마다 새로 채워져요.';

class AssistUsageSection extends StatefulWidget {
  const AssistUsageSection({super.key, this.assist, this.credits});

  /// 테스트에서 끼워 넣는다. 비우면 서버를 부른다.
  final SentenceAssist? assist;

  /// 패롯으로 예문 몫을 사는 길. 테스트에서 끼워 넣는다.
  final ExampleCreditsService? credits;

  @override
  State<AssistUsageSection> createState() => _AssistUsageSectionState();
}

class _AssistUsageSectionState extends State<AssistUsageSection> {
  late final SentenceAssist _assist = widget.assist ??
      // 앱에 하나 있는 것을 받는다(5차 564). 없는 곳(테스트)에서는 새로 만든다.
      context.read<CloudSentenceAssist?>() ??
      CloudSentenceAssist();
  late final ExampleCreditsService _credits =
      widget.credits ?? ExampleCreditsService();
  bool _loading = true;
  bool _buying = false;

  /// 아직 끝나지 않은 구매의 요청 id(5차 534). 예문·뜻발음 따로 센다.
  ///
  /// 응답이 늦어 타임아웃이 나도 **서버는 끝냈을 수 있다**. 기기에서 실제로
  /// 그랬다 - 패롯 3개가 깎였는데 화면은 '사지 못했어요'였다. 다시 누를 때
  /// 새 id를 만들면 두 번 깎인다. 성공할 때까지 같은 id를 들고 있는다.
  final Map<bool, String> _pendingBuyIds = {};

  /// 패롯으로 한 묶음 산다. 끝나면 성공이든 아니든 남은 수를 다시 읽는다.
  Future<void> _buy({bool assist = false}) async {
    if (_buying) return;
    setState(() => _buying = true);
    final requestId =
        _pendingBuyIds[assist] ??= ExampleCreditsService.newRequestId();
    try {
      final result = await _credits.buy(requestId: requestId, assist: assist);
      // 서버가 받아들였다. 같은 id를 다시 쓸 일은 없다.
      _pendingBuyIds.remove(assist);
      if (!mounted) return;
      // bought가 0이면 아까 타임아웃 난 그 요청이 이미 반영된 것이다.
      if (result.bought <= 0) {
        showToast(exampleCreditAlreadyMessage);
      } else {
        // 산 몫도 광고 패롯·복습 크래커와 같은 덮개로 띄운다(5차, 사용자
        // 요청). 글 한 줄은 패롯을 내고 받은 것치고 눈에 안 띄었다.
        await showAssistCelebration(
          context,
          amount: result.bought,
          kind: assist ? AssistKind.meaning : AssistKind.example,
        );
      }
    } on ExampleCreditsFailed catch (e) {
      if (mounted) showToast(e.message);
    } finally {
      // 갔는지 모르는 채로 끝났어도 서버 값을 다시 읽어 화면을 맞춘다.
      // 전에는 실패 경로에서 안 읽어서, 몫은 들어왔는데 화면에 안 보였다.
      //
      // 몫을 사는 것은 다른 함수라 받아 둔 숫자가 그대로다. 버리고 물어야
      // 새 몫이 보인다(5차 564).
      final assist = _assist;
      if (assist is CloudSentenceAssist) assist.invalidateUsage();
      await _load();
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading) setState(() => _loading = true);
    await _assist.refreshUsage();
    if (mounted) setState(() => _loading = false);
  }

  /// 오늘 쓴 수. 서버가 한도와 남은 수를 둘 다 줬을 때만 셀 수 있다.
  ///
  /// 남은 수에는 사 둔 몫이 더해져 온다. 그대로 빼면 음수가 나온다 -
  /// 기기에서 '예문 생성 -5 / 10개'가 떴다(5차 535). 사 둔 몫을 먼저 뺀다.
  int? _used(int? limit, int? remaining, int credits) => assistUsedToday(
        limit: limit,
        remaining: remaining,
        credits: credits,
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tier = context.watch<SubscriptionProvider>().tier;

    // 서버가 준 한도를 먼저 쓴다. 없으면 이 단계의 기본값을 적는다 —
    // 숫자가 아예 없는 것보다 낫고, 서버가 설정으로 바꿨으면 그 값이 이긴다.
    final basicsLimit = _assist.dailyLimit ?? dailyAssistFor(tier);
    final examplesLimit = _assist.exampleDailyLimit ?? dailyExamplesFor(tier);
    final basicsUsed = _used(_assist.dailyLimit, _assist.remainingToday,
        _assist.assistCredits ?? 0);
    final examplesUsed = _used(_assist.exampleDailyLimit,
        _assist.examplesRemainingToday, _assist.exampleCredits ?? 0);
    final unknown = !_loading && basicsUsed == null && examplesUsed == null;
    final credits = _assist.exampleCredits ?? 0;
    final assistCredits = _assist.assistCredits ?? 0;
    final parrots = context.watch<UserProvider>().currentUser?.spendableParrots;
    final cantBuy = exampleCreditBlocked(parrots: parrots);
    final cantBuyAssist = assistCreditBlocked(parrots: parrots);

    return Container(
      key: const ValueKey('assist-usage-section'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        // 카드 표준 라운딩(AppRadius.card)에 맞춘다. lg(16)는 지갑 카드처럼
        // 큰 덩이에 쓰고, 그 아래 딸린 이 카드는 한 단계 작게 둔다(5차 533).
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // labelLarge는 버튼 글자용이라 색이 onPrimary(흰색)다
                // (app_texts_theme.dart:110). 그대로 쓰면 밝은 바탕에서
                // 글자가 사라진다 - 기기에서 제목이 안 보였다(5차 533).
                // 캘린더의 _MeterRow가 같은 데 걸려 색을 적어 두고 있다.
                child: Text(assistUsageSectionTitle,
                    style: context.texts.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    )),
              ),
              if (_loading)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _UsageRow(
            kind: AssistKind.meaning,
            label: assistUsageBasicsLabel,
            value: assistUsageCount(basicsUsed, basicsLimit, '번', assistCredits),
            // 사 둔 몫이 남아 있으면 다 쓴 것이 아니다(5차). 그냥
            // used >= limit으로 보면 '3 / 3번 +5'가 빨갛게 떠서, 바로 아래
            // 단추로 산 몫 5번이 못 쓰는 것처럼 보였다. 문장 추가·단어 쪽은
            // 처음부터 assistExhausted를 썼으므로 같은 상태를 두 화면이
            // 다르게 말했다.
            exhausted: assistExhausted(
                used: basicsUsed, limit: basicsLimit, credits: assistCredits),
            rowKey: const ValueKey('assist-usage-basics'),
          ),
          const SizedBox(height: 6),
          _UsageRow(
            kind: AssistKind.example,
            label: assistUsageExamplesLabel,
            // 단위는 '번'으로 맞춘다(5차 562, 사용자 요청).
            value: assistUsageCount(examplesUsed, examplesLimit, '번', credits),
            exhausted: assistExhausted(
                used: examplesUsed, limit: examplesLimit, credits: credits),
            rowKey: const ValueKey('assist-usage-examples'),
          ),
          const SizedBox(height: 10),
          if (unknown)
            // 못 읽었을 때 숫자만 '—'로 남겨 두면 고장으로 보인다.
            // 문장 추가 화면과 같은 말로, 눌러서 다시 물어볼 수 있게 한다.
            InkWell(
              key: const ValueKey('assist-usage-retry'),
              onTap: _load,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(assistUsageUnknownLabel,
                    style: context.texts.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
              ),
            )
          else ...[
            Text(
              tier == SubscriptionTier.free
                  ? '$assistUsageResetHint $assistQuotaUpsellText'
                  : assistUsageResetHint,
              key: const ValueKey('assist-usage-hint'),
              style:
                  context.texts.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            // 두 단추를 가로로 나란히 둔다(사용자 요청, 5차 536). 글이 길면
            // 안 들어가므로 값은 빼고 아래 안내 줄에 한 번만 적는다.
            // 살 수 없으면 까닭을 단추 아래에 적는다. 눌리는데 아무 일도
            // 없는 단추를 오늘만 세 번 고쳤다(519·525·526).
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('assist-usage-buy-assist'),
                    style: _buyButtonStyle(context, cs),
                    onPressed: _buying || cantBuyAssist != null
                        ? null
                        : () => _buy(assist: true),
                    child: _buying
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _buyLabel(AssistKind.meaning,
                            assistCreditBuyLabel(1),
                            semantics: assistCreditBuySemantics(1)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('assist-usage-buy'),
                    style: _buyButtonStyle(context, cs),
                    onPressed: _buying || cantBuy != null ? null : () => _buy(),
                    child: _buying
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _buyLabel(AssistKind.example,
                            exampleCreditBuyLabel(1),
                            semantics: exampleCreditBuySemantics(1)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(creditPackPriceHint(1),
                  key: const ValueKey('assist-usage-price'),
                  style: context.texts.bodySmall
                      .copyWith(color: cs.onSurfaceVariant)),
            ),
            if (cantBuy != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(cantBuy,
                    key: const ValueKey('assist-usage-buy-blocked'),
                    style: context.texts.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
              ),
          ],
        ],
      ),
    );
  }
}

/// 사기 단추 모양. 기본 단추는 AppRadius.button(= full)이라 알약 모양이다.
/// 흰 바탕에 각을 줄여 둔다(사용자 요청). 지갑 카드의 단추와 같은 결이되
/// 라운딩만 한 단계 작다.
ButtonStyle _buyButtonStyle(BuildContext context, ColorScheme cs) =>
    FilledButton.styleFrom(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      disabledBackgroundColor: cs.surface.withValues(alpha: 0.6),
      disabledForegroundColor: cs.onSurfaceVariant,
      elevation: 0,
      minimumSize: const Size.fromHeight(44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle:
          context.texts.labelLarge.copyWith(fontWeight: FontWeight.w700),
    );

/// 사기 단추 속 그림 + 말. 두 단추가 좁게 나란히 서므로 그림은 작게 둔다.
Widget _buyLabel(AssistKind kind, String text, {required String semantics}) =>
    Semantics(
      label: semantics,
      // 글은 '+5'뿐이라 눈으로는 옆 그림이 무엇인지 말해 주지만,
      // 읽어 주는 쪽에는 그 그림이 없다(5차 567).
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AssistIcon(kind, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.kind,
    required this.label,
    required this.value,
    required this.exhausted,
    required this.rowKey,
  });

  final AssistKind kind;
  final String label;
  final String value;
  final bool exhausted;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      key: rowKey,
      children: [
        // 패롯·크래커 줄과 같은 결로, 무엇의 한도인지 그림으로 먼저 보인다.
        AssistIcon(kind, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: context.texts.bodyMedium
                  .copyWith(color: cs.onSurfaceVariant)),
        ),
        Text(
          value,
          style: context.texts.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            // 다 쓴 줄만 빨갛게. 문장 추가 화면과 같은 규칙이다(5차 475).
            color: exhausted ? cs.error : cs.onSurface,
          ),
        ),
      ],
    );
  }
}
