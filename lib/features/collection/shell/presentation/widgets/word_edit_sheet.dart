// 낱말 고치기. 뜻·발음·유의어·예문을 한 화면에서 고친다(5차 469, 사용자 요청).
//
// 전에는 항목마다 작은 창이 따로 떴다. 뜻 고치기, 발음 적기, 유의어 적기,
// 예문 하나씩 고치기가 각각 다른 시기에 붙은 탓이다. 한 낱말을 손보려면
// 창을 네 번 열었다 닫아야 했다.
//
// 저장은 한 번에 한다(MyWordStore.saveEdits).
//
// 자동 채우기도 여기 둔다(5차 470, 사용자 지적). 상세에만 있었더니, 예문을
// 손보러 이 창에 들어온 사람이 자동으로 받으려면 창을 닫고 나가야 했다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/example_count_sheet.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';

/// 고치기 시트를 연다. 저장했으면 바뀐 낱말을 돌려준다.
Future<MyWord?> showWordEditSheet(
  BuildContext context, {
  required MyWord word,
  required String accountId,
  SentenceAssist? assist,
}) =>
    showAppSheet<MyWord>(
      context: context,
      builder: (_) => WordEditSheet(
        word: word,
        accountId: accountId,
        assist: assist,
      ),
    );

class WordEditSheet extends StatefulWidget {
  const WordEditSheet({
    super.key,
    required this.word,
    required this.accountId,
    this.assist,
  });

  final MyWord word;
  final String accountId;

  /// 테스트에서 가짜를 넣는 자리. 비우면 서버를 부른다.
  final SentenceAssist? assist;

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

  late final SentenceAssist _assist = widget.assist ?? CloudSentenceAssist();

  bool _saving = false;
  bool _filling = false;
  bool _fillingExamples = false;

  /// 오늘 남은 횟수. 이 창은 열릴 때 한 번 물어본다(5차 473).
  /// 전에는 아예 묻지 않아서, 다 쓴 뒤에도 단추가 눌렸다.
  bool _usageChecked = false;

  bool get _exhausted => _usageChecked &&
      assistExhausted(
        used: _assist.dailyLimit == null || _assist.remainingToday == null
            ? null
            : _assist.dailyLimit! - _assist.remainingToday!,
        limit: _assist.dailyLimit,
      );

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _exampleTexts.length; i++) {
      _watchExample(_exampleTexts[i], _exampleMeanings[i]);
    }
    _assist.refreshUsage().then((_) {
      if (mounted) setState(() => _usageChecked = true);
    }).catchError((_) {
      // 못 읽어도 단추는 쓸 수 있게 둔다. 서버가 막으면 그때 알린다.
      if (mounted) setState(() => _usageChecked = false);
    });
  }
  String? _notice;

  /// 지금 저장을 막는 까닭. 누르기 전에 보여 준다(5차 504).
  ///
  /// 빈 예문 칸은 그냥 버리지만, **뜻만 적어 둔 칸**은 버리면 적은 글이
  /// 말없이 사라진다.
  String? get _blocked {
    final at = wordExampleMissingTextAt(
      [for (final c in _exampleTexts) c.text],
      [for (final c in _exampleMeanings) c.text],
    );
    return at == null ? null : wordExampleNeedsTextMessage(at);
  }

  /// 적는 대로 단추와 안내가 따라 바뀐다.
  void _watchExample(TextEditingController text, TextEditingController meaning) {
    text.addListener(_onExampleChanged);
    meaning.addListener(_onExampleChanged);
  }

  void _onExampleChanged() {
    if (mounted) setState(() {});
  }

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
      final text = TextEditingController();
      final meaning = TextEditingController();
      _watchExample(text, meaning);
      _exampleTexts.add(text);
      _exampleMeanings.add(meaning);
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

  /// 뜻과 발음만 받아 빈 칸을 채운다(5차 472, 사용자 요청).
  ///
  /// 예문은 아래 '예문 채우기'가 맡는다. 둘은 쓰임이 다르다 - 뜻·발음은
  /// 한 번 채우면 끝이고 예문은 여러 개를 더 받는다.
  Future<void> _fillBasics() async {
    if (_filling || _saving) return;
    if (_meaning.text.trim().isNotEmpty &&
        _pronunciation.text.trim().isNotEmpty) {
      setState(() => _notice = '뜻과 발음을 이미 적어 두었어요.');
      return;
    }
    setState(() {
      _filling = true;
      _notice = null;
    });
    String? note;
    try {
      // count 0이면 서버가 예문을 만들지 않는다.
      final suggestion = await _assist.suggestWord(
        language: widget.word.language,
        word: widget.word.word,
        count: 0,
      );
      if (!mounted) return;
      final meaning = suggestion.translation?.trim() ?? '';
      final sound = suggestion.pronunciation?.trim() ?? '';
      if (_meaning.text.trim().isEmpty && meaning.isNotEmpty) {
        _meaning.text = meaning;
      }
      if (_pronunciation.text.trim().isEmpty && sound.isNotEmpty) {
        _pronunciation.text = sound;
      }
      if (meaning.isEmpty && sound.isEmpty) {
        note = '받지 못했어요. 잠시 뒤 다시 해 주세요.';
      }
    } on SentenceAssistQuotaExceeded {
      note = assistQuotaExhaustedMessage;
    } on SentenceAssistUnavailable catch (e) {
      note = e.reason;
    } catch (_) {
      note = '받지 못했어요. 잠시 뒤 다시 해 주세요.';
    } finally {
      if (mounted) {
        setState(() {
          _filling = false;
          _notice = note;
        });
      }
    }
  }

  /// 예문만 받는다(5차 472, 사용자 요청).
  ///
  /// 아직 저장하지 않은 입력칸을 그대로 쓰고, 지금 칸의 예문을 겹치지
  /// 않게 서버로 함께 보낸다.
  Future<void> _fillExamples() async {
    if (_fillingExamples || _saving) return;
    final room = examplesMaxCount - _exampleTexts.length;
    final emptySlots = [
      for (final (index, c) in _exampleTexts.indexed)
        if (c.text.trim().isEmpty) index,
    ];
    if (room <= 0 && emptySlots.isEmpty) {
      setState(() => _notice = '예문은 $examplesMaxCount개까지 넣을 수 있어요.');
      return;
    }
    final count = await askExampleCount(
      context,
      room: emptySlots.length + room < 1 ? 1 : emptySlots.length + room,
      already: [
        for (final c in _exampleTexts)
          if (c.text.trim().isNotEmpty) c,
      ].length,
    );
    if (!mounted || count == null) return;

    setState(() {
      _fillingExamples = true;
      _notice = null;
    });
    String? note;
    try {
      final suggestion = await _assist.suggestWord(
        language: widget.word.language,
        word: widget.word.word,
        existingExamples: [
          for (final c in _exampleTexts)
            if (c.text.trim().isNotEmpty) c.text.trim(),
        ],
        count: count,
      );
      if (!mounted) return;
      var slot = 0;
      for (final example in suggestion.examples) {
        if (slot < emptySlots.length) {
          final at = emptySlots[slot];
          _exampleTexts[at].text = example.text;
          _exampleMeanings[at].text = example.translation;
        } else {
          if (_exampleTexts.length >= examplesMaxCount) break;
          _exampleTexts.add(TextEditingController(text: example.text));
          _exampleMeanings
              .add(TextEditingController(text: example.translation));
          _exampleSources.add('');
        }
        slot++;
      }
      if (suggestion.examples.isEmpty) {
        note = '예문을 받지 못했어요. 잠시 뒤 다시 해 주세요.';
      }
    } on SentenceAssistQuotaExceeded {
      note = assistQuotaExhaustedMessage;
    } on SentenceAssistUnavailable catch (e) {
      note = e.reason;
    } catch (_) {
      note = '예문을 받지 못했어요. 잠시 뒤 다시 해 주세요.';
    } finally {
      if (mounted) {
        setState(() {
          _fillingExamples = false;
          _notice = note;
        });
      }
    }
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
    // 막힌 까닭이 있으면 그것부터 적는다. 꺼진 단추 바로 위다(5차 504).
    final blocked = _blocked;
    final notice = blocked ?? _notice;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.word.word,
                      style: context.texts.headlineSmall),
                ),
                // 예문을 손보러 들어온 자리에서 바로 받을 수 있게 한다(5차 470).
                TextButton.icon(
                  key: const ValueKey('edit-word-fill'),
                  onPressed:
                      _filling || _saving || _exhausted ? null : _fillBasics,
                  icon: _filling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('뜻·발음 채우기'),
                ),
              ],
            ),
            // 무엇을 채우는지 적는다. 추가 시트와 같은 말이다(5차 472).
            Text(
              _exhausted ? assistQuotaExhaustedMessage : wordFillBasicsHint,
              key: const ValueKey('edit-word-autofill-hint'),
              style: context.texts.bodySmall
                  .copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
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
            // 예문 단추는 예문 칸 옆에 둔다(5차 472, 사용자 요청).
            Row(
              children: [
                Expanded(
                  child: Text('예문', style: context.texts.titleMedium),
                ),
                TextButton.icon(
                  key: const ValueKey('edit-word-fill-examples'),
                  onPressed: _fillingExamples || _saving || _exhausted
                      ? null
                      : _fillExamples,
                  icon: _fillingExamples
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('예문 채우기'),
                ),
              ],
            ),
            Text(
              _exhausted ? assistQuotaExhaustedMessage : wordFillExamplesHint,
              key: const ValueKey('edit-word-examples-hint'),
              style:
                  context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant),
            ),
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
                onPressed: _saving || blocked != null ? null : _save,
                child: Text(_saving ? '저장 중…' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
