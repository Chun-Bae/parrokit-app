import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

import 'folder_tree.dart';

/// 폴더 고르기. 폴더 경로('여행/일본')는 저장 방식일 뿐이라 사용자가 '/'를 직접
/// 칠 일이 없게 한다(5차, 사용자 의견). 있는 폴더를 트리로 보여주고 눌러서 고르며,
/// 줄의 + 로 그 안에 새 폴더를 만든다. 고른 경로를 돌려준다.
Future<String?> showFolderPicker(
  BuildContext context, {
  required Iterable<String> existingNames,
  String? selected,
}) =>
    showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FolderPickerSheet(
        existingNames: existingNames.toList(),
        selected: selected == null ? null : normalizeFolderPath(selected),
      ),
    );

/// 새 폴더 이름을 받는다. '/'는 경로 구분이라 쓸 수 없다. [parentName]이 있으면
/// 그 안에 만든다는 것을 제목으로 알려준다.
///
/// [createsNow]면 '만들기'를 누르는 대로 폴더가 생긴다(보관함의 '새 폴더').
/// 아니면 클립 만들기의 폴더 고르기처럼 첫 클립을 저장할 때 생긴다.
Future<String?> showNewFolderDialog(BuildContext context,
        {String? parentName, bool createsNow = false}) =>
    showDialog<String>(
      context: context,
      builder: (_) =>
          _NewFolderDialog(parentName: parentName, createsNow: createsNow),
    );

/// 폴더 이름 바꾸기. [currentName]을 채워 열고 새 이름(마지막 칸)을 돌려준다.
Future<String?> showRenameFolderDialog(BuildContext context,
        {required String currentName}) =>
    showDialog<String>(
      context: context,
      builder: (_) =>
          _NewFolderDialog(initialName: currentName, renaming: true),
    );

class _FolderPickerSheet extends StatefulWidget {
  const _FolderPickerSheet({required this.existingNames, this.selected});

  final List<String> existingNames;
  final String? selected;

  @override
  State<_FolderPickerSheet> createState() => _FolderPickerSheetState();
}

class _FolderPickerSheetState extends State<_FolderPickerSheet> {
  List<ClipFolder> get _roots {
    final names = widget.existingNames;
    // 빈 폴더도 고를 수 있게 이름마다 1을 준다(트리는 빈 폴더를 빼므로).
    final (roots, _) = buildFolderTree(
      [for (var i = 0; i < names.length; i++) (i, names[i])],
      {for (var i = 0; i < names.length; i++) i: 1},
    );
    return roots;
  }

  Future<void> _create(ClipFolder? parent) async {
    final name = await showNewFolderDialog(context, parentName: parent?.name);
    if (!mounted || name == null) return;
    final path = parent == null ? name : '${parent.path}/$name';
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    void add(ClipFolder folder, int depth) {
      final selected = folder.path == widget.selected;
      rows.add(Material(
        color: selected ? context.tokens.primarySoft : Colors.transparent,
        child: InkWell(
          key: ValueKey('pick-folder-${folder.path}'),
          onTap: () => Navigator.pop(context, folder.path),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16 + depth * 20.0, 4, 4, 4),
            child: Row(children: [
              Icon(
                  folder.children.isEmpty
                      ? Icons.folder_rounded
                      : Icons.folder_copy_rounded,
                  size: 20,
                  color: context.tokens.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyLarge.copyWith(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500)),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: context.tokens.primary),
              IconButton(
                key: ValueKey('new-folder-in-${folder.path}'),
                tooltip: "'${folder.name}' 안에 새 폴더",
                onPressed: () => _create(folder),
                icon: Icon(Icons.create_new_folder_outlined,
                    size: 20, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
        ),
      ));
      for (final child in folder.children) {
        add(child, depth + 1);
      }
    }

    for (final root in _roots) {
      add(root, 0);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(children: [
                Expanded(
                    child: Text('폴더 고르기', style: context.texts.titleLarge)),
                TextButton.icon(
                  key: const ValueKey('new-root-folder'),
                  onPressed: () => _create(null),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('새 폴더'),
                ),
              ]),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Text('아직 폴더가 없어요. 새 폴더를 만들어 주세요.',
                    style: context.texts.bodyMedium
                        .copyWith(color: cs.onSurfaceVariant)),
              )
            else
              Flexible(child: ListView(shrinkWrap: true, children: rows)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog({
    this.parentName,
    this.createsNow = false,
    this.initialName,
    this.renaming = false,
  });

  final String? parentName;
  final bool createsNow;
  final String? initialName;
  final bool renaming;

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _error =>
      _controller.text.contains('/') ? "'/'는 쓸 수 없어요" : null;

  bool get _valid =>
      _controller.text.trim().isNotEmpty &&
      _error == null &&
      // 이름 바꾸기에서 그대로면 할 일이 없다.
      !(widget.renaming && _controller.text.trim() == widget.initialName);

  void _submit() {
    if (_valid) Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.renaming
          ? '폴더 이름 바꾸기'
          : widget.parentName == null
              ? '새 폴더'
              : "'${widget.parentName}' 안에 새 폴더"),
      content: TextField(
        key: const ValueKey('new-folder-name'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: '폴더 이름',
          errorText: _error,
          // 글자 수 표시와 한 줄을 나눠 쓰므로 짧게.
          helperText: widget.createsNow || widget.renaming
              ? null
              : '첫 클립을 넣으면 생겨요',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          key: const ValueKey('confirm-new-folder'),
          onPressed: _valid ? _submit : null,
          child: Text(widget.renaming ? '바꾸기' : '만들기'),
        ),
      ],
    );
  }
}
