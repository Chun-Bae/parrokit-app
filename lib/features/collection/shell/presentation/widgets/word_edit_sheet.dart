// 낱말 고치기. 뜻·발음·유의어·예문을 한 화면에서 고친다(5차 469, 사용자 요청).
//
// 전에는 항목마다 작은 창이 따로 떴다. 뜻 고치기, 발음 적기, 유의어 적기,
// 예문 하나씩 고치기가 각각 다른 시기에 붙은 탓이다. 한 낱말을 손보려면
// 창을 네 번 열었다 닫아야 했다.
//
// 저장은 한 번에 한다(MyWordStore.saveEdits).

import 'package:flutter/material.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 고치기 시트를 연다. 저장했으면 바뀐 낱말을 돌려준다.
Future<MyWord?> showWordEditSheet(
  BuildContext context, {
  required MyWord word,
  required String accountId,
}) =>
    showAppSheet<MyWord>(
      context: context,
      builder: (_) => WordEditSheet(word: word, accountId: accountId),
    );

class WordEditSheet extends StatefulWidget {
  const WordEditSheet({
    super.key,
    required this.word,
    required this.accountId,
  });

  final MyWord word;
  final String accountId;

  @override
  State<WordEditSheet> createState() => _WordEditSheetState();
}

class _WordEditSheetState extends State<WordEditSheet> {
  late final _meaning = TextEditingController(text: widget.word.meaning);
  late final _pronunciation =
      TextEditingController(text: widget.word.pronunciation);
  late final _synonymInput = TextEditingController();
  late List<String> _synonyms = [...widget.word.synonyms];

  /// 예문마다 원문·뜻 입력칸을 짝으로 둔다. 문장에서 저장한 예문은
  /// 그 문장과의 연결(sourceSentenceId)을 그대로 들고 간다.
  late final List<TextEditingController> _exampleTexts = [
    for (final e in widget.word.examples) TextEditingController(text: e.text),
  ];
  late final List<TextEditingController> _exampleMeanings = [
    for (final e in widget.word.examples)
      TextEditingController(text: e.translation),
  ];
  late final List<String> _exampleSources = [
    for (final e in widget.word.examples) e.sourceSentenceId,
  ];

  bool _saving = false;
  String? _notice;

  @override
  void dispose() {
    _meaning.dispose();
    _pronunciation.dispose();
    _synonymInput.dispose();
    for (final c in [..._exampleTexts, ..._exampleMeanings]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSynonym() {
    final one = _synonymInput.text.trim();
    if (one.isEmpty) return;
    if (_synonyms.length >= synonymsMaxCount) {
      setState(() => _notice = '유의어는 $synonymsMaxCount개까지 넣을 수 있어요.');
      return;
    }
    if (_synonyms.any((s) => s.toLowerCase() == one.toLowerCase())) {
      setState(() => _notice = '이미 있는 유의어예요.');
      return;
    }
    setState(() {
      _synonyms = [..._synonyms, one];
      _synonymInput.clear();
      _notice = null;
    });
  }

  void _addExampleField() {
    if (_exampleTexts.length >= examplesMaxCount) {
      setState(() => _notice = '예문은 $examplesMaxCount개까지 넣을 수 있어요.');
      return;
    }
    setState(() {
      _exampleTexts.add(TextEditingController());
      _exampleMeanings.add(TextEditingController());
      _exampleSources.add('');
      _notice = null;
    });
  }

  void _removeExampleField(int index) {
    setState(() {
      _exampleTexts.removeAt(index).dispose();
      _exampleMeanings.removeAt(index).dispose();
      _exampleSources.removeAt(index);
      _notice = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    // 비어 있는 예문 칸은 버린다. 칸만 열어 두고 저장해도 괜찮아야 한다.
    final examples = <WordExample>[
      for (final (index, c) in _exampleTexts.indexed)
        if (c.text.trim().isNotEmpty)
          WordExample(
            text: c.text.trim(),
            translation: _exampleMeanings[index].text.trim(),
            sourceSentenceId: _exampleSources[index],
          ),
    ];
    final saved = await MyWordStore.saveEdits(
      widget.accountId,
      widget.word.id,
      meaning: _meaning.text,
      pronunciation: _pronunciation.text,
      synonyms: _synonyms,
      examples: examples,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _saving = false;
        _notice = saveFailedMessage;
      });
      return;
    }
    Navigator.of(context).pop(widget.word.copyWith(
      meaning: _meaning.text.trim(),
      pronunciation: _pronunciation.text.trim(),
      synonyms: _synonyms,
      examples: examples,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final notice = _notice;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.word.word, style: context.texts.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('edit-word-meaning-input'),
              controller: _meaning,
              maxLength: meaningMaxLength,
              decoration: const InputDecoration(
                labelText: meaningOptionalLabel,
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              key: const ValueKey('edit-word-pronunciation-input'),
              controller: _pronunciation,
              maxLength: meaningMaxLength,
              decoration: const InputDecoration(
                labelText: pronunciationOptionalLabel,
                hintText: '한글로 소리 나는 대로',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('edit-word-synonym-input'),
                    controller: _synonymInput,
                    onSubmitted: (_) => _addSynonym(),
                    decoration: const InputDecoration(
                      labelText: '유의어 (비워도 돼요)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('edit-word-synonym-add'),
                  onPressed: _addSynonym,
                  child: const Text('추가'),
                ),
              ],
            ),
            if (_synonyms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (index, one) in _synonyms.indexed)
                    InputChip(
                      key: ValueKey('edit-word-synonym-$index'),
                      label: Text(one),
                      onDeleted: () => setState(
                          () => _synonyms = [..._synonyms]..removeAt(index)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('예문', style: context.texts.titleMedium),
            for (final (index, controller) in _exampleTexts.indexed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: ValueKey('edit-word-example-$index'),
                            controller: controller,
                            maxLength: 300,
                            maxLines: 2,
                            minLines: 1,
                            decoration: InputDecoration(
                              labelText: '예문 ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          key: ValueKey('edit-word-example-remove-$index'),
                          tooltip: '이 예문 빼기',
                          onPressed: () => _removeExampleField(index),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                    TextField(
                      key: ValueKey('edit-word-example-meaning-$index'),
                      controller: _exampleMeanings[index],
                      maxLength: 300,
                      maxLines: 2,
                      minLines: 1,
                      decoration: const InputDecoration(
                        labelText: '예문 뜻 (비워도 돼요)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_exampleTexts.length < examplesMaxCount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('edit-word-example-add'),
                  onPressed: _addExampleField,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('예문 더 넣기'),
                ),
              ),
            if (notice != null) ...[
              const SizedBox(height: 8),
              Text(notice,
                  key: const ValueKey('edit-word-notice'),
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('edit-word-save'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중…' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
