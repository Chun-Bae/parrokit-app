import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/content/add_sentence_controller.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';

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
    const muted = Color(0xFF61758D);
    return Scaffold(
      appBar: AppBar(title: const Text('문장 추가')),
      // 키보드가 올라와도 가려지지 않게 추가 버튼은 아래에 고정한다.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              controller.text,
              controller.translation,
            ]),
            builder: (context, _) => FilledButton(
              key: const ValueKey('save-sentence'),
              onPressed: controller.canSave ? save : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('추가'),
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
              if (controller.canTransliterate) ...[
                _HangulTransliterateRow(controller: controller),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const ValueKey('sentence-text'),
                controller: controller.text,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                maxLength: 80,
                maxLines: null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '원문',
                  hintText: '연습할 문장을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: controller.text,
                builder: (context, _) => _AutoFillCard(controller: controller),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('sentence-translation'),
                controller: controller.translation,
                style: const TextStyle(fontSize: 16),
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
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('sentence-pronunciation'),
                controller: controller.pronunciation,
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '발음 (선택)',
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.fillStatus == AssistStatus.loading
                      ? const _LoadingDot()
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                  child: Text('원문과 뜻은 꼭 필요해요. 발음은 비워둬도 돼요.',
                      style: TextStyle(color: muted, fontSize: 12))),
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

/// 키보드로 치기 어려운 언어를 한글 소리로 적어 원문으로 바꾼다.
class _HangulTransliterateRow extends StatelessWidget {
  const _HangulTransliterateRow({required this.controller});
  final AddSentenceController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.transliterateStatus;
    final example = controller.language == '일본어' ? '곤니치와' : '니하오';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: TextField(
          key: const ValueKey('sentence-hangul'),
          controller: controller.hangul,
          style: const TextStyle(fontSize: 16),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.transliterate(),
          decoration: InputDecoration(
            labelText: '한글로 소리 적기',
            hintText: '예: $example',
            border: const OutlineInputBorder(),
          ),
        )),
        const SizedBox(width: 8),
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.tonal(
                key: const ValueKey('transliterate'),
                onPressed: status == AssistStatus.loading
                    ? null
                    : controller.transliterate,
                style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
                child: status == AssistStatus.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('변환'))),
      ]),
      if (status == AssistStatus.unavailable ||
          status == AssistStatus.failed ||
          status == AssistStatus.quotaExceeded)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                switch (status) {
                  AssistStatus.unavailable =>
                    '지금은 한글 변환을 쓸 수 없어요. 원문을 직접 입력해주세요.',
                  AssistStatus.quotaExceeded => '오늘 횟수를 모두 썼어요. 내일 다시 쓸 수 있어요.',
                  _ => '변환하지 못했어요. 다시 시도하거나 원문을 직접 입력해주세요.',
                },
                key: const ValueKey('transliterate-message'),
                style:
                    const TextStyle(color: Color(0xFF61758D), fontSize: 12))),
    ]);
  }
}

/// 뜻·발음 채우기 버튼과 그 옆에 오늘 쓴 횟수("1 / 3")를 보여준다.
class _AutoFillCard extends StatelessWidget {
  const _AutoFillCard({required this.controller});
  final AddSentenceController controller;

  String? get message => switch (controller.fillStatus) {
        AssistStatus.unavailable =>
          '지금은 자동 채우기를 쓸 수 없어요. 로그인했는지 확인하거나 직접 입력해주세요.',
        AssistStatus.quotaExceeded => '오늘 횟수를 모두 썼어요. 내일 다시 쓸 수 있어요.',
        AssistStatus.failed => '자동으로 채우지 못했어요. 횟수는 줄지 않았어요.',
        AssistStatus.loading => '채우는 중이에요…',
        AssistStatus.idle => null,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = controller.fillStatus;
    final used = controller.usedToday;
    final limit = controller.dailyLimit;
    final exhausted = status == AssistStatus.quotaExceeded ||
        (used != null && limit != null && used >= limit);
    final note = message;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        FilledButton.tonalIcon(
          key: const ValueKey('auto-fill-now'),
          onPressed: controller.text.text.trim().isEmpty ||
                  status == AssistStatus.loading ||
                  exhausted
              ? null
              : controller.fill,
          icon: status == AssistStatus.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(status == AssistStatus.failed ? '다시 채우기' : '뜻·발음 채우기',
              style: const TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 12),
        if (used != null && limit != null)
          Text('$used / $limit',
              key: const ValueKey('usage-count'),
              style: TextStyle(
                  color: exhausted ? colors.error : colors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600))
        else if (controller.usageStatus == UsageStatus.loading)
          Text('횟수 확인 중…',
              key: const ValueKey('usage-loading'),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))
        else
          // 못 읽었을 때도 아무것도 안 보이지 않게, 다시 확인할 수 있게 안내한다.
          InkWell(
            key: const ValueKey('usage-unknown'),
            onTap: controller.loadUsage,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text('횟수를 확인하지 못했어요 · 탭해서 다시 확인',
                  style:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
            ),
          ),
      ]),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(note,
              key: const ValueKey('auto-fill-message'),
              style: TextStyle(
                  color: exhausted ? colors.error : colors.onSurfaceVariant,
                  fontSize: 12)),
        ),
    ]);
  }
}
