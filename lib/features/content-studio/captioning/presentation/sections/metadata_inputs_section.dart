import 'package:flutter/material.dart';
import '../../data/constants/edit_strings.dart';
import '../providers/captioning_provider.dart';
import 'package:parrokit/features/collection/library/presentation/folder_picker_sheet.dart';
import 'package:parrokit/features/collection/library/presentation/folder_tree.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class MetadataInputsSection extends StatelessWidget {
  const MetadataInputsSection({super.key, required this.vm});

  final CaptioningProvider vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 폴더. 예전엔 이름을 직접 치는 칸이라 폴더 안의 폴더에 넣으려면
          // '/'를 쳐야 했다. 이제 눌러서 트리에서 고르고, 새 폴더도 거기서 만든다.
          _FolderField(vm: vm),

          Divider(height: 1, color: context.tokens.dividerSubtle),

          // 2. 클립 제목
          _LinearInputField(
            label: EditStrings.clipTitleLabel,
            hint: EditStrings.clipTitleHint,
            controller: vm.titleCtl,
          ),

          Divider(height: 1, color: context.tokens.dividerSubtle),

          // 3. 태그
          _LinearInputField(
            label: EditStrings.tagsLabel,
            hint: EditStrings.tagsHint,
            controller: vm.tagsCtl,
            trailing: TextButton(
              onPressed: () {
                final tag = vm.tagsCtl.text.trim();
                if (tag.isNotEmpty) {
                  vm.addTag(tag);
                  vm.tagsCtl.clear();
                }
              },
              child: const Text('추가'),
            ),
            onSubmitted: (val) {
              final tag = val.trim();
              if (tag.isNotEmpty) {
                vm.addTag(tag);
                vm.tagsCtl.clear();
              }
            },
          ),

          if (vm.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: -8,
              children: vm.tags
                  .map((tag) => Chip(
                        label: Text(tag, style: theme.textTheme.bodySmall),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        padding: const EdgeInsets.all(0),
                        onDeleted: () => vm.removeTag(tag),
                        backgroundColor: context.tokens.surfaceContainerHigh,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LinearInputField extends StatefulWidget {
  const _LinearInputField({
    required this.label,
    required this.hint,
    required this.controller,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  State<_LinearInputField> createState() => _LinearInputFieldState();
}

class _LinearInputFieldState extends State<_LinearInputField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70, // 고정 너비로 제목 정렬
            child: Text(
              widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onTapOutside: (_) => _focusNode.unfocus(),
              onSubmitted: widget.onSubmitted,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                filled: false,
                // 포커싱이 안될 땐 투명하게 안보이게 (InputBorder.none)
                // 포커싱 될 때만 primary color 밑줄 적용
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}

/// 폴더 칸. 고른 경로를 "여행 › 일본"처럼 보여주고, 누르면 폴더 고르기를 연다.
class _FolderField extends StatelessWidget {
  const _FolderField({required this.vm});

  final CaptioningProvider vm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: vm.collectionNameCtl,
      builder: (context, value, _) {
        final path = normalizeFolderPath(value.text);
        return InkWell(
          key: const ValueKey('caption-folder-field'),
          onTap: () async {
            FocusScope.of(context).unfocus();
            final picked = await showFolderPicker(
              context,
              existingNames: vm.allCollectionNames,
              selected: path.isEmpty ? null : path,
            );
            if (picked != null) vm.collectionNameCtl.text = picked;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              SizedBox(
                width: 70,
                child: Text(EditStrings.collectionLabel,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Icon(Icons.folder_rounded,
                  size: 18,
                  color: path.isEmpty ? cs.outline : context.tokens.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path.isEmpty ? EditStrings.collectionHint : path.split('/').join(' › '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: path.isEmpty ? cs.outline : cs.onSurface),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ]),
          ),
        );
      },
    );
  }
}
