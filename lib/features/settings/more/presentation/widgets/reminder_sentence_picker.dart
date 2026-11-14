import 'package:flutter/material.dart';

import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 연습 알림에 쓸 문장을 고르는 창. 아무것도 안 고르면 내 문장 전부를 쓴다.
///
/// 고른 결과(문장 id)를 돌려준다. 닫기만 하면 null.
Future<Set<String>?> showReminderSentencePicker({
  required BuildContext context,
  required List<DefaultConversationSentence> sentences,
  required Set<String> chosen,
}) {
  return showAppSheet<Set<String>>(
    context: context,
    builder: (context) => _ReminderSentencePicker(
      sentences: sentences,
      chosen: chosen,
    ),
  );
}

class _ReminderSentencePicker extends StatefulWidget {
  const _ReminderSentencePicker({
    required this.sentences,
    required this.chosen,
  });

  final List<DefaultConversationSentence> sentences;
  final Set<String> chosen;

  @override
  State<_ReminderSentencePicker> createState() =>
      _ReminderSentencePickerState();
}

class _ReminderSentencePickerState extends State<_ReminderSentencePicker> {
  late final Set<String> _chosen = {...widget.chosen};

  /// 지금 모두 골라 둔 상태인지. 하나도 안 골랐으면 false라서 '전체'를 누르면
  /// 모두 골라진다(비었을 때 눌러도 아무 일이 없으면 안 된다).
  bool get _all =>
      widget.sentences.isNotEmpty && _chosen.length == widget.sentences.length;

  void _toggleAll() {
    setState(() {
      if (_all) {
        _chosen.clear();
      } else {
        _chosen
          ..clear()
          ..addAll(widget.sentences.map((s) => s.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sentences = widget.sentences;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('알림에 쓸 문장',
                      style: context.texts.titleLarge
                          .copyWith(fontWeight: FontWeight.w800)),
                ),
                TextButton(
                  key: const ValueKey('reminder-pick-all'),
                  onPressed: sentences.isEmpty ? null : _toggleAll,
                  child: Text(_all ? '모두 지우기' : '전체 고르기'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _chosen.isEmpty
                    ? '고른 문장이 없으면 내 문장을 모두 써요'
                    : '${_chosen.length}개를 골랐어요',
                style: context.texts.bodySmall
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
          Flexible(
            child: sentences.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 32),
                    child: Text('저장한 문장이 없어요. 문장을 먼저 저장해 주세요.',
                        style: context.texts.bodyMedium
                            .copyWith(color: cs.onSurfaceVariant)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: sentences.length,
                    itemBuilder: (context, index) {
                      final sentence = sentences[index];
                      final on = _chosen.contains(sentence.id);
                      return CheckboxListTile(
                        value: on,
                        onChanged: (next) => setState(() {
                          if (next == true) {
                            _chosen.add(sentence.id);
                          } else {
                            _chosen.remove(sentence.id);
                          }
                        }),
                        title: Text(sentence.text,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: sentence.translation.trim().isEmpty
                            ? null
                            : Text(sentence.translation,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('reminder-pick-done'),
                onPressed: () => Navigator.of(context).pop(_chosen),
                child: const Text('다 골랐어요'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
