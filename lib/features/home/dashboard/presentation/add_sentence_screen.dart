import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'dart:async';

import 'package:flutter/material.dart';

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
  final sentence = await Navigator.of(context, rootNavigator: true)
      .push<AddedSentence>(MaterialPageRoute(
    builder: (_) =>
        AddSentenceScreen(language: language, assist: CloudSentenceAssist()),
  ));
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
    final muted = HomeTokens.of(context).muted;
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('문장 추가'),
          // 횟수는 단추 셋이 함께 쓰는 것이라 어느 한 단추 옆에 둘 수
          // 없었다. 화면 머리로 올린다(5차 542, 사용자 요청).
          actions: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _UsageAction(controller: controller),
            ),
          ],
        ),
        // 키보드가 올라와도 가려지지 않게 추가 버튼은 아래에 고정한다.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                controller.text,
                controller.translation,
              ]),
              builder: (context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const ValueKey('save-sentence'),
                    onPressed: controller.canSave ? save : null,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('추가'),
                  ),
                  // 꺼진 버튼만 보고는 무엇이 빠졌는지 알 수 없었다(5차,
                  // 커뮤니티 글쓰기와 같게).
                  if (controller.blockedReason case final reason?) ...[
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      key: const ValueKey('add-sentence-blocked-reason'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                LearningLanguagePicker(
                  key: const ValueKey('sentence-language'),
                  value: controller.language,
                  onChanged: controller.setLanguage,
                ),
                const SizedBox(height: 16),
                // 원문칸도 뜻·발음칸처럼 단추를 오른쪽에 둔다(5차 542,
                // 사용자 요청). 전에는 이 칸만 단추가 아래에 있었다.
                ListenableBuilder(
                  listenable: controller.text,
                  builder: (context, _) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('sentence-text'),
                          controller: controller.text,
                          style: context.texts.titleLarge,
                          maxLength: sentenceMaxLength,
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '원문',
                            hintText: '연습할 문장을 적어 주세요',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _FillButton(controller: controller),
                      ),
                    ],
                  ),
                ),
                ListenableBuilder(
                  listenable: controller.text,
                  builder: (context, _) =>
                      _AutoFillCard(controller: controller),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 4),
                // 만들기 단추는 뜻칸과 원문칸이 바뀔 때 나타나고 사라진다.
                ListenableBuilder(
                  listenable: Listenable.merge(
                      [controller.translation, controller.text]),
                  builder: (context, _) =>
                      _TranslationRow(controller: controller),
                ),
                const SizedBox(height: 12),
                // 원문 만들기 단추는 발음칸과 원문칸이 바뀔 때 나타나고
                // 사라진다. 본문 전체를 다시 그리지 않도록 이 줄만 듣는다.
                ListenableBuilder(
                  listenable: Listenable.merge(
                      [controller.pronunciation, controller.text]),
                  builder: (context, _) =>
                      _PronunciationRow(controller: controller),
                ),
                const SizedBox(height: 16),
                Center(
                    child: Text('원문과 뜻은 꼭 필요해요. 발음은 비워도 돼요.',
                        style: context.texts.bodySmall.copyWith(color: muted))),
              ],
            ),
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

/// 뜻칸과 그 옆의 '만들기'(뜻 → 원문, 5차 540, 사용자 요청).
///
/// 한글 전사는 소리를 알아야 쓴다. 뜻만 아는 경우가 더 흔해서 반대 길을
/// 둔다. 원문이 비어 있거나 자동으로 채운 값일 때만 단추가 보인다.
class _TranslationRow extends StatelessWidget {
  const _TranslationRow({required this.controller});
  final AddSentenceController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.composeStatus;
    // 만드는 중이거나 횟수를 읽는 중. 둘 다 기다리는 것이라 같이 다룬다.
    final busy = status == AssistStatus.loading ||
        controller.usageStatus == UsageStatus.loading;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            key: const ValueKey('sentence-translation'),
            controller: controller.translation,
            style: context.texts.titleMedium,
            maxLines: null,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '뜻',
              border: const OutlineInputBorder(),
              suffixIcon: controller.fillStatus == AssistStatus.loading
                  ? const _LoadingDot()
                  : null,
            ),
          ),
        ),
        if (controller.canCompose) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.tonal(
              key: const ValueKey('compose-from-meaning'),
              // 뜻·발음 채우기, 한글 변환과 같은 하루 횟수를 나눠 쓴다.
              onPressed:
                  busy || controller.exhausted ? null : controller.compose,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(makeSentenceLabel),
            ),
          ),
        ],
      ]),
      if (status == AssistStatus.unavailable ||
          status == AssistStatus.failed ||
          status == AssistStatus.quotaExceeded)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            switch (status) {
              AssistStatus.unavailable => '지금은 원문 만들기를 쓸 수 없어요. 원문을 직접 적어 주세요.',
              AssistStatus.quotaExceeded => assistQuotaExhaustedMessage,
              _ => '원문을 만들지 못했어요. 다시 해 보거나 직접 적어 주세요.',
            },
            key: const ValueKey('compose-message'),
            style: context.texts.bodySmall.copyWith(
                color: status == AssistStatus.quotaExceeded
                    ? Theme.of(context).colorScheme.error
                    : HomeTokens.of(context).muted),
          ),
        ),
    ]);
  }
}

/// 발음칸과 그 옆의 '원문 만들기'(발음 → 원문, 5차 541, 사용자 요청).
///
/// 전에는 일본어·중국어 전용 '한글로 소리 적기' 칸이 따로 있었다. 발음칸에
/// 같은 것을 또 적게 하는 꼴이어서 그 칸을 걷어내고 여기로 모았다. 영어에서도
/// '헬로 데어'로 "Hello there"를 받는다.
class _PronunciationRow extends StatelessWidget {
  const _PronunciationRow({required this.controller});
  final AddSentenceController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.transliterateStatus;
    // 만드는 중이거나 횟수를 읽는 중. 둘 다 기다리는 것이라 같이 다룬다.
    final busy = status == AssistStatus.loading ||
        controller.usageStatus == UsageStatus.loading;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            key: const ValueKey('sentence-pronunciation'),
            controller: controller.pronunciation,
            style: context.texts.bodyMedium,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: pronunciationOptionalLabel,
              border: const OutlineInputBorder(),
              suffixIcon: controller.fillStatus == AssistStatus.loading
                  ? const _LoadingDot()
                  : null,
            ),
          ),
        ),
        if (controller.canMakeFromSound) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.tonal(
              key: const ValueKey('transliterate'),
              // 뜻·발음 채우기와 같은 하루 횟수를 나눠 쓴다(5차 478).
              onPressed:
                  busy || controller.exhausted ? null : controller.transliterate,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(makeSentenceLabel),
            ),
          ),
        ],
      ]),
      if (status == AssistStatus.unavailable ||
          status == AssistStatus.failed ||
          status == AssistStatus.quotaExceeded)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            switch (status) {
              AssistStatus.unavailable => '지금은 원문 만들기를 쓸 수 없어요. 원문을 직접 적어 주세요.',
              AssistStatus.quotaExceeded => assistQuotaExhaustedMessage,
              _ => '원문을 만들지 못했어요. 다시 해 보거나 직접 적어 주세요.',
            },
            key: const ValueKey('transliterate-message'),
            style: context.texts.bodySmall.copyWith(
                color: status == AssistStatus.quotaExceeded
                    ? Theme.of(context).colorScheme.error
                    : HomeTokens.of(context).muted),
          ),
        ),
    ]);
  }
}

/// '뜻발음 생성' 단추(5차 542에 원문칸 오른쪽으로 옮겼다).
class _FillButton extends StatelessWidget {
  const _FillButton({required this.controller});
  final AddSentenceController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.fillStatus;
    final exhausted =
        status == AssistStatus.quotaExceeded || controller.exhausted;
    return FilledButton.tonal(
      key: const ValueKey('auto-fill-now'),
      // 횟수를 읽는 동안에는 누르지 못하게 한다(5차 516). 다 썼는지
      // 모르는 채로 눌리면, 이미 바닥난 사람이 서버에 한 번 더
      // 부딪히고 나서야 '다 썼어요'를 본다.
      onPressed: controller.text.text.trim().isEmpty ||
              status == AssistStatus.loading ||
              controller.usageStatus == UsageStatus.loading ||
              exhausted ||
              !controller.hasFillRoom
          ? null
          : controller.fill,
      style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
      child: status == AssistStatus.loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text(status == AssistStatus.failed ? '다시 생성' : fillBasicsLabel),
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
    final exhausted = controller.exhausted;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: used != null && limit != null
            // 숫자만 있으면("0 / 3") 쓴 횟수인지 남은 횟수인지 알 수 없었다.
            ? Text(assistUsageShortLabel(used: used, limit: limit)!,
                key: const ValueKey('usage-count'),
                style: context.texts.bodySmall.copyWith(
                    color: exhausted ? colors.error : colors.onSurfaceVariant))
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
        AssistStatus.unavailable =>
          '지금은 자동 채우기를 쓸 수 없어요. 로그인했는지 확인하거나 직접 적어 주세요.',
        // 소진 안내는 단어 쪽과 같은 말을 쓴다(5차 475).
        AssistStatus.quotaExceeded => assistQuotaExhaustedMessage,
        AssistStatus.failed => '자동으로 채우지 못했어요. 횟수는 줄지 않았어요.',
        AssistStatus.loading => '채우는 중이에요…',
        // 다 쓴 줄은 눌러 보기 전에도 안다. 횟수부터 보고 말한다(5차 478).
        AssistStatus.idle => controller.exhausted
            ? assistQuotaExhaustedMessage
            : controller.text.text.trim().isEmpty
                ? assistNeedsTextHint('문장')
                // 손으로 다 적어 두면 채우기가 덮어쓸 자리가 없다. 눌러도
                // 아무 일이 없으니 까닭을 적고 단추를 끈다(5차 526).
                : !controller.hasFillRoom
                    ? assistBasicsDoneMessage
                    : null,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = controller.fillStatus;
    final exhausted =
        status == AssistStatus.quotaExceeded || controller.exhausted;
    final note = message;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
