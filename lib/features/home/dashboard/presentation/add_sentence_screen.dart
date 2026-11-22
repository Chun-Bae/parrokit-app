import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/shared/theme/components/inputs/app_input_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';

import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/content/add_sentence_controller.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/shared/widgets/draft_pop_scope.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 문장 추가 화면을 하단 네비바 위로 열어 저장까지 한다. 취소하면 null.
/// 저장에 실패하면 예외를 그대로 던지니 부른 쪽에서 안내한다.
Future<({AddedSentence sentence, bool added})?> addSentenceFlow(
  BuildContext context, {
  required String accountId,
  required String language,
}) async {
  // 내가 추가한 문장에는 내 닉네임을 남긴다.
  final author = context.read<UserProvider?>()?.currentUser?.displayName ?? '';
  // 한도 조회는 앱에 하나 있는 것을 쓴다(5차 564).
  final assist = context.read<CloudSentenceAssist?>() ?? CloudSentenceAssist();
  // 단어 추가와 같은 꼴로 바텀시트에 띄운다(5차 565, 사용자 요청).
  final sentence = await showAppSheet<AddedSentence>(
    context: context,
    builder: (_) => AddSentenceScreen(language: language, assist: assist),
  );
  if (sentence == null) return null;
  final added = await MySentenceStore.add(
    accountId,
    language: sentence.language,
    text: sentence.text,
    translation: sentence.translation,
    pronunciation: sentence.pronunciation,
    author: author,
  );
  return (sentence: sentence, added: added);
}

/// 연습할 문장을 원문, 뜻, 발음(선택)으로 추가하는 화면.
/// 언어는 화면에서 고른다. 저장하면 입력값을 [AddedSentence]로 돌려준다.
class AddSentenceScreen extends StatefulWidget {
  const AddSentenceScreen({
    super.key,
    required this.language,
    this.assist = const UnavailableSentenceAssist(),
  });

  final String language;
  final SentenceAssist assist;

  @override
  State<AddSentenceScreen> createState() => _AddSentenceScreenState();
}

class _AddSentenceScreenState extends State<AddSentenceScreen> {
  late final controller = AddSentenceController(
    language: widget.language,
    assist: widget.assist,
  );

  @override
  void initState() {
    super.initState();
    // 오늘 쓴 횟수를 미리 보여 준다. 모델을 부르지 않아 횟수를 쓰지 않는다.
    unawaited(controller.loadUsage());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    final sentence = controller.build();
    if (sentence != null) Navigator.pop(context, sentence);
  }

  @override
  Widget build(BuildContext context) {
    // 원문·뜻·발음 중 하나라도 적었으면 나갈 때 묻는다(5차). 예전엔 뒤로 한 번에
    // 사라졌다. 추가에 성공하면 Navigator.pop으로 바로 닫혀 묻지 않는다.
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.text,
        controller.translation,
        controller.pronunciation,
      ]),
      builder: (context, child) => DraftPopScope(
        hasDraft: [
          controller.text,
          controller.translation,
          controller.pronunciation,
        ].any((c) => c.text.trim().isNotEmpty),
        child: child!,
      ),
      // 바텀시트로 띄운다(5차 565, 사용자 요청). 단어 추가와 같은 꼴이다.
      // 시트 밖(테스트)에서도 칸이 그려지게 Material을 하나 둔다. 색은
      // 시트가 칠하므로 여기서는 비워 둔다.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        20, AppSpacing.lg, 20, AppSpacing.sm),
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => _body(),
                    ),
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 머리. 제목과 오늘 쓴 횟수를 한 줄에 둔다(5차 542·565).
  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: Text('문장 추가', style: context.texts.titleLarge),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.tokens.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => _UsageAction(controller: controller),
              ),
            ),
          ],
        ),
      );

  Widget _body() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LearningLanguagePicker(
            key: const ValueKey('sentence-language'),
            value: controller.language,
            onChanged: controller.setLanguage,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 꼭 적어야 하는 칸만 별표를 단다(5차 565, 사용자 요청).
          // 테두리는 없애고 면으로 그린다. 단어 추가와 같은 꼴이다.
          TextField(
            key: const ValueKey('sentence-text'),
            controller: controller.text,
            style: context.texts.titleMedium,
            maxLength: sentenceMaxLength,
            maxLines: null,
            textInputAction: TextInputAction.next,
            decoration: filledInputDecoration(
              context,
              label: requiredFieldLabel('원문'),
              hint: '연습할 문장을 적어 주세요',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('sentence-translation'),
            controller: controller.translation,
            style: context.texts.bodyLarge,
            maxLines: null,
            textInputAction: TextInputAction.next,
            decoration: filledInputDecoration(
              context,
              label: requiredFieldLabel('뜻'),
              suffixIcon: controller.fillStatus == AssistStatus.loading
                  ? const _LoadingDot()
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('sentence-pronunciation'),
            controller: controller.pronunciation,
            style: context.texts.bodyMedium,
            textInputAction: TextInputAction.done,
            decoration: filledInputDecoration(
              context,
              label: wordPronunciationLabel,
              hint: '한글로 소리 나는 대로',
              suffixIcon: controller.fillStatus == AssistStatus.loading
                  ? const _LoadingDot()
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // 단추 하나가 셋을 다 한다(5차 545, 사용자 요청). 어느 한
          // 칸에 매이지 않으므로 세 칸 아래에 가로로 길게 둔다.
          ListenableBuilder(
            listenable: Listenable.merge([
              controller.text,
              controller.translation,
              controller.pronunciation,
            ]),
            builder: (context, _) => _AutoFillCard(controller: controller),
          ),
        ],
      );

  /// 바닥. 키보드가 올라와도 추가 단추는 제자리에 있는다.
  Widget _footer() {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: context.tokens.dividerSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: ListenableBuilder(
          listenable: Listenable.merge([
            controller.text,
            controller.translation,
          ]),
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save-sentence'),
                  onPressed: controller.canSave ? save : null,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: const Text('추가'),
                ),
              ),
              // 꺼진 버튼만 보고는 무엇이 빠졌는지 알 수 없었다(5차,
              // 커뮤니티 글쓰기와 같게).
              if (controller.blockedReason case final reason?) ...[
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  reason,
                  key: const ValueKey('add-sentence-blocked-reason'),
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDot extends StatelessWidget {
  const _LoadingDot();

  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.all(14),
      child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2)));
}

/// 빈 칸을 채우는 단추 하나(5차 545, 사용자 요청).
class _FillButton extends StatelessWidget {
  const _FillButton({required this.controller});
  final AddSentenceController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.fillStatus;
    final exhausted =
        status == AssistStatus.quotaExceeded || controller.exhausted;
    // 채우는 중이거나 횟수를 읽는 중. 둘 다 기다리는 것이라 같이 다룬다
    // (5차 539). 쉬다 깨는 첫 조회는 15초를 넘기는데 그동안 단추가 회색으로
    // 죽어만 있으면 고장으로 보인다.
    final busy = status == AssistStatus.loading ||
        controller.usageStatus == UsageStatus.loading;
    return FilledButton.tonal(
      key: const ValueKey('auto-fill-now'),
      // 횟수를 읽는 동안에는 누르지 못하게 한다(5차 516). 다 썼는지
      // 모르는 채로 눌리면, 이미 바닥난 사람이 서버에 한 번 더
      // 부딪히고 나서야 '다 썼어요'를 본다.
      onPressed: !controller.hasFillSource ||
              controller.hasRivalSources ||
              busy ||
              exhausted ||
              !controller.hasFillRoom
          ? null
          : controller.fill,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              const AssistIcon(AssistKind.meaning, size: 18),
              const SizedBox(width: 8),
              Text(status == AssistStatus.failed ? '다시 생성' : fillBasicsLabel),
            ]),
    );
  }
}

/// 앱바 오른쪽에 오늘 쓴 횟수를 보여 준다(5차 542, 사용자 요청).
///
/// 전에는 '뜻발음 생성' 단추 옆에 있었다. 그런데 '원문 생성' 둘까지 같은
/// 주머니를 쓰게 되면서, 한 단추 옆에 붙여 두면 그 단추만의 횟수로
/// 읽혔다. 셋 위에 한 번만 적는다.
class _UsageAction extends StatelessWidget {
  const _UsageAction({required this.controller});
  final AddSentenceController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final used = controller.usedToday;
    final limit = controller.dailyLimit;
    return Center(
      widthFactor: 1,
      child: Builder(
        builder: (context) => used != null && limit != null
            // 숫자만 있으면("0 / 3") 쓴 횟수인지 남은 횟수인지 알 수 없었다.
            // 단어 추가 시트와 같은 꼴로 적는다(5차 560, 사용자 요청).
            // 전에는 여기만 '오늘 2/3회 +1'이라고 말이 길었다.
            ? AssistUsagePair(
                key: const ValueKey('usage-count'),
                kind: AssistKind.meaning,
                used: used,
                limit: limit,
                credits: controller.assistCredits ?? 0,
              )
            : controller.usageStatus == UsageStatus.loading
                ? Text(assistUsageLoadingLabel,
                    key: const ValueKey('usage-loading'),
                    style: context.texts.bodySmall
                        .copyWith(color: colors.onSurfaceVariant))
                // 못 읽었을 때도 아무것도 안 보이지 않게, 다시 확인할 수
                // 있게 안내한다. 앱바는 좁아서 짧게 적는다.
                : InkWell(
                    key: const ValueKey('usage-unknown'),
                    onTap: controller.loadUsage,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: Text(assistUsageUnknownShortLabel,
                          style: context.texts.bodySmall
                              .copyWith(color: colors.onSurfaceVariant)),
                    ),
                  ),
      ),
    );
  }
}

/// 뜻·발음 채우기 버튼과 그 옆에 오늘 쓴 횟수("1 / 3")를 보여준다.
class _AutoFillCard extends StatelessWidget {
  const _AutoFillCard({required this.controller});
  final AddSentenceController controller;

  /// 단추 아래에 적을 말. 막혀 있으면 까닭부터 말한다(5차 475).
  ///
  /// 전에는 문장을 아직 안 적어 단추가 흐릴 때 아무 말도 없었다. 단어
  /// 화면에서 같은 결함을 고쳤는데(474) 이쪽에 그대로 남아 있었다.
  String? get message => switch (controller.fillStatus) {
        AssistStatus.unavailable => '지금은 채우기를 쓸 수 없어요. 로그인했는지 확인하거나 직접 적어 주세요.',
        // 소진 안내는 단어 쪽과 같은 말을 쓴다(5차 475).
        AssistStatus.quotaExceeded => assistQuotaExhaustedMessage,
        AssistStatus.failed => '자동으로 채우지 못했어요. 횟수는 줄지 않았어요.',
        AssistStatus.loading => '채우는 중이에요…',
        // 다 쓴 줄은 눌러 보기 전에도 안다. 횟수부터 보고 말한다(5차 478).
        AssistStatus.idle => controller.exhausted
            ? assistQuotaExhaustedMessage
            // 셋 가운데 하나만 적어도 나머지를 채운다(5차 545).
            : !controller.hasFillSource
                ? fillNeedsAnyFieldHint
                // 원문을 뜻과 발음 둘에서 만들면 어긋날 수 있다(5차 553).
                : controller.hasRivalSources
                    ? fillRivalSourcesMessage
                    // 손으로 다 적어 두면 채우기가 덮어쓸 자리가 없다.
                    // 눌러도 아무 일이 없으니 까닭을 적는다(5차 526).
                    : !controller.hasFillRoom
                        ? fillNothingLeftMessage
                        : null,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = controller.fillStatus;
    final exhausted =
        status == AssistStatus.quotaExceeded || controller.exhausted;
    final note = message;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _FillButton(controller: controller),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(note,
              key: const ValueKey('auto-fill-message'),
              style: context.texts.bodySmall.copyWith(
                  // 빨강은 '다 썼다'에만 쓴다. 아직 안 적어서 막힌 것은
                  // 그냥 안내다(5차 475).
                  color: note == assistQuotaExhaustedMessage
                      ? colors.error
                      : colors.onSurfaceVariant)),
        ),
      // 다 쓴 무료 사용자에게만, 더 쓸 수 있는 길을 한 줄로 알린다(5차 구독 3단계).
      if (exhausted &&
          context.watch<SubscriptionProvider>().tier == SubscriptionTier.free)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(
                child: Text(assistQuotaUpsellText,
                    key: const ValueKey('assist-quota-upsell'),
                    style: context.texts.bodySmall
                        .copyWith(color: colors.onSurfaceVariant))),
            TextButton(
                key: const ValueKey('assist-quota-subscribe'),
                onPressed: () => resolvePaywallPresenter().show(context),
                child: const Text(subscriptionOpenButtonLabel)),
          ]),
        ),
    ]);
  }
}
