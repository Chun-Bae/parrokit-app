import 'package:flutter/material.dart';
import 'package:parrokit/core/app/router/app_shell.dart' show hideNavBarWhile;
import 'package:parrokit/core/content/sentence_transfer.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 가져오기 시트에서 "완료"로 확정한 결과. 취소하거나 닫으면 시트는 null을 돌려준다.
class SentenceImportResult {
  const SentenceImportResult({required this.added});

  final int added;
}

/// 파일·주소에서 읽은 문장을 바로 등록하지 않고 목록으로 먼저 보여준다.
/// 빼고 싶은 문장은 체크를 풀고, "가져오기"를 누르면 하나씩 옮기며 진행 상황을 보여준다.
/// 다 옮기면 "완료"로 확정하거나 "취소"로 방금 가져온 문장을 모두 되돌릴 수 있다.
///
/// [addOne]은 문장 하나를 등록하고 새 문장의 id를 돌려준다. 이미 있어서 등록하지 않았으면 null,
/// 등록했지만 id를 알 수 없으면 빈 문자열(되돌릴 수 없다)을 돌려준다.
/// [removeOne]은 [addOne]이 돌려준 id의 문장을 지운다.
Future<SentenceImportResult?> showSentenceImportSheet(
  BuildContext context, {
  required List<ImportedSentence> items,
  required String defaultLanguage,
  required Set<String> existingKeys,
  required Future<String?> Function(ImportedSentence item) addOne,
  required Future<void> Function(String id) removeOne,
}) =>
    hideNavBarWhile(showModalBottomSheet<SentenceImportResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: false,
      builder: (context) => SentenceImportSheet(
        items: items,
        defaultLanguage: defaultLanguage,
        existingKeys: existingKeys,
        addOne: addOne,
        removeOne: removeOne,
      ),
    ));

/// 언어와 문장으로 같은 문장인지 가리는 키.
String sentenceImportKey(String language, String text) =>
    '$language\u0000${text.trim()}';

/// 외국어 이름을 오른쪽에 작은 칩으로 보여준다.
class _LanguageChip extends StatelessWidget {
  const _LanguageChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('import-language-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(label,
          style: context.texts.labelSmall
              .copyWith(color: colors.onSecondaryContainer)),
    );
  }
}

enum _Phase { select, running, done, undoing }

enum _ItemState { pending, adding, added, skipped, failed }

class SentenceImportSheet extends StatefulWidget {
  const SentenceImportSheet({
    super.key,
    required this.items,
    required this.defaultLanguage,
    required this.existingKeys,
    required this.addOne,
    required this.removeOne,
  });

  final List<ImportedSentence> items;
  final String defaultLanguage;
  final Set<String> existingKeys;
  final Future<String?> Function(ImportedSentence item) addOne;
  final Future<void> Function(String id) removeOne;

  @override
  State<SentenceImportSheet> createState() => _SentenceImportSheetState();
}

class _SentenceImportSheetState extends State<SentenceImportSheet> {
  static const _rowHeight = 68.0;

  final _scroll = ScrollController();
  _Phase _phase = _Phase.select;

  /// 가져올 문장으로 고른 항목의 번호. 이미 있는 문장은 고를 수 없다.
  late final Set<int> _selected;

  /// 이미 내 문장에 있거나 파일 안에서 앞에 같은 문장이 있는 항목.
  late final Set<int> _duplicates;

  /// 옮기는 순서(고른 항목)와 항목별 상태, 새로 등록한 문장의 id.
  List<int> _queue = const [];
  final Map<int, _ItemState> _states = {};
  final Map<int, String> _addedIds = {};
  int _processed = 0;

  /// 옮기는 도중 취소를 눌렀는지. 지금 옮기는 문장까지만 마치고 멈춘 뒤 되돌린다.
  bool _cancelRequested = false;

  /// 도중에 취소해서 옮기지 않은 문장 수.
  int _notStarted = 0;

  String _languageOf(ImportedSentence item) =>
      item.language.isEmpty ? widget.defaultLanguage : item.language;

  @override
  void initState() {
    super.initState();
    final seen = <String>{...widget.existingKeys};
    _duplicates = {};
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (!seen.add(sentenceImportKey(_languageOf(item), item.text))) {
        _duplicates.add(i);
      }
    }
    _selected = {
      for (var i = 0; i < widget.items.length; i++)
        if (!_duplicates.contains(i)) i,
    };
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _busy => _phase == _Phase.running || _phase == _Phase.undoing;

  int get _addedCount =>
      _states.values.where((s) => s == _ItemState.added).length;

  void _scrollTo(int position) {
    if (!_scroll.hasClients) return;
    final target = (position * _rowHeight - _rowHeight * 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  Future<void> _start() async {
    final queue = (_selected.toList()..sort());
    setState(() {
      _queue = queue;
      _phase = _Phase.running;
      _processed = 0;
      for (final i in queue) {
        _states[i] = _ItemState.pending;
      }
    });
    var stopped = false;
    for (var position = 0; position < queue.length; position++) {
      if (!mounted) return;
      if (_cancelRequested) {
        // 취소를 눌렀으면 여기까지 옮긴 문장만 남기고 멈춘다.
        stopped = true;
        _queue = queue.sublist(0, position);
        _notStarted = queue.length - position;
        break;
      }
      final index = queue[position];
      setState(() => _states[index] = _ItemState.adding);
      _scrollTo(position);
      _ItemState next;
      try {
        final id = await widget.addOne(widget.items[index]);
        if (id == null) {
          next = _ItemState.skipped;
        } else {
          next = _ItemState.added;
          _addedIds[index] = id;
        }
      } catch (_) {
        next = _ItemState.failed;
      }
      if (!mounted) return;
      setState(() {
        _states[index] = next;
        _processed = position + 1;
      });
    }
    if (!mounted) return;
    // 마지막 문장을 옮기는 중에 취소를 눌렀다면 모두 옮긴 것으로 본다.
    setState(() {
      if (stopped) _scrollTo(0);
      _phase = _Phase.done;
    });
  }

  /// 방금 가져온 문장을 모두 지우고 고르는 목록으로 돌아간다.
  /// 고른 상태는 그대로라서, 잘못 고른 문장만 빼고 다시 가져올 수 있다.
  Future<void> _undo() async {
    final targets = _addedIds.entries.where((e) => e.value.isNotEmpty).toList();
    setState(() {
      _phase = _Phase.undoing;
      _processed = 0;
    });
    for (var i = 0; i < targets.length; i++) {
      try {
        await widget.removeOne(targets[i].value);
      } catch (_) {/* 지우지 못한 문장은 그대로 남는다. */}
      if (!mounted) return;
      setState(() => _processed = i + 1);
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.select;
      _queue = const [];
      _states.clear();
      _addedIds.clear();
      _processed = 0;
      _notStarted = 0;
      _cancelRequested = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _finish() =>
      Navigator.of(context).pop(SentenceImportResult(added: _addedCount));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        // 완료 상태에서 밖을 눌러 닫으면 가져온 그대로 확정한다.
      },
      child: SizedBox(
        key: const ValueKey('import-sheet'),
        height: height,
        child: Column(
          children: [
            _header(colors),
            const Divider(height: 1),
            Expanded(child: _list(colors)),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
              child: _footer(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme colors) {
    final total = widget.items.length;
    final title = switch (_phase) {
      _Phase.select => '가져올 문장 $total개',
      _Phase.running => '문장을 옮기는 중이에요',
      _Phase.done => _notStarted > 0 ? '여기까지 옮겼어요' : '옮기기가 끝났어요',
      _Phase.undoing => '가져온 문장을 되돌리는 중이에요',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.texts.titleLarge),
              if (_phase == _Phase.select) ...[
                const SizedBox(height: 2),
                Text(
                  _duplicates.isEmpty
                      ? '빼고 싶은 문장은 체크를 풀어주세요.'
                      : '빼고 싶은 문장은 체크를 풀어주세요. 이미 있는 ${_duplicates.length}개는 제외돼요.',
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (_phase == _Phase.select)
          TextButton(
            key: const ValueKey('import-toggle-all'),
            onPressed: () => setState(() {
              final selectable = {
                for (var i = 0; i < total; i++)
                  if (!_duplicates.contains(i)) i,
              };
              if (_selected.length == selectable.length) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(selectable);
              }
            }),
            child: Text(_selected.length == total - _duplicates.length
                ? '전체 해제'
                : '전체 선택'),
          ),
      ]),
    );
  }

  Widget _list(ColorScheme colors) {
    final selecting = _phase == _Phase.select;
    final count = selecting ? widget.items.length : _queue.length;
    return ListView.builder(
      key: const ValueKey('import-list'),
      controller: _scroll,
      itemExtent: _rowHeight,
      itemCount: count,
      itemBuilder: (context, position) {
        final index = selecting ? position : _queue[position];
        final item = widget.items[index];
        final duplicate = _duplicates.contains(index);
        final detail = [
          if (item.translation.isNotEmpty) item.translation,
          if (selecting && duplicate) '이미 있어요',
        ].join(' · ');
        final chip = _LanguageChip(_languageOf(item));
        if (selecting) {
          return CheckboxListTile(
            key: ValueKey('import-item-$index'),
            value: _selected.contains(index),
            onChanged: duplicate
                ? null
                : (value) => setState(() => value == true
                    ? _selected.add(index)
                    : _selected.remove(index)),
            controlAffinity: ListTileControlAffinity.leading,
            title:
                Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle:
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
            secondary: chip,
          );
        }
        final state = _states[index] ?? _ItemState.pending;
        return ListTile(
          key: ValueKey('import-item-$index'),
          leading: SizedBox(
              width: 24, height: 24, child: Center(child: _stateIcon(state))),
          title: Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              state == _ItemState.skipped
                  ? [if (detail.isNotEmpty) detail, '이미 있어요'].join(' · ')
                  : detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: chip,
        );
      },
    );
  }

  Widget _stateIcon(_ItemState state) => switch (state) {
        _ItemState.pending =>
          const Icon(Icons.radio_button_unchecked, size: 20),
        _ItemState.adding => const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
        _ItemState.added => Icon(Icons.check_circle_rounded,
            size: 20, color: Theme.of(context).colorScheme.primary),
        _ItemState.skipped => const Icon(Icons.remove_circle_outline, size: 20),
        _ItemState.failed => Icon(Icons.error_outline_rounded,
            size: 20, color: Theme.of(context).colorScheme.error),
      };

  Widget _footer(ColorScheme colors) {
    switch (_phase) {
      case _Phase.select:
        return Row(children: [
          TextButton(
            key: const ValueKey('import-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          const Spacer(),
          FilledButton(
            key: const ValueKey('import-start'),
            onPressed: _selected.isEmpty ? null : _start,
            child: Text('${_selected.length}개 가져오기'),
          ),
        ]);
      case _Phase.running:
      case _Phase.undoing:
        final running = _phase == _Phase.running;
        final total = _phase == _Phase.running
            ? _queue.length
            : _addedIds.values.where((id) => id.isNotEmpty).length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
                value: total == 0 ? null : _processed / total),
            const SizedBox(height: 8),
            const SizedBox(height: 0),
            Row(children: [
              Text(
                  _cancelRequested && running
                      ? '멈추는 중… $_processed / $total'
                      : '$_processed / $total',
                  key: const ValueKey('import-progress-count'),
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
              const Spacer(),
              if (running)
                TextButton(
                  key: const ValueKey('import-running-cancel'),
                  onPressed: _cancelRequested
                      ? null
                      : () => setState(() => _cancelRequested = true),
                  child: const Text('취소'),
                ),
            ]),
          ],
        );
      case _Phase.done:
        final skipped =
            _states.values.where((s) => s == _ItemState.skipped).length;
        final failed =
            _states.values.where((s) => s == _ItemState.failed).length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                _notStarted > 0
                    ? '도중에 멈췄어요. 여기까지 $_addedCount개를 가져왔어요.'
                    : '$_addedCount개를 가져왔어요.',
                if (_notStarted > 0) '나머지 $_notStarted개는 가져오지 않았어요.',
                if (skipped > 0) '이미 있는 $skipped개는 건너뛰었어요.',
                if (failed > 0) '$failed개는 가져오지 못했어요.',
              ].join(' '),
              key: const ValueKey('import-summary'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
                _notStarted > 0
                    ? '"완료"는 여기까지 가져온 문장을 남기고, "취소"는 되돌리고 목록으로 돌아가요.'
                    : '"취소"를 누르면 방금 가져온 문장을 되돌리고 목록으로 돌아가요.',
                style: context.texts.bodySmall
                    .copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('import-undo'),
                  onPressed: _addedIds.values.any((id) => id.isNotEmpty)
                      ? _undo
                      : null,
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('import-done'),
                  onPressed: _finish,
                  child: const Text('완료'),
                ),
              ),
            ]),
          ],
        );
    }
  }
}
