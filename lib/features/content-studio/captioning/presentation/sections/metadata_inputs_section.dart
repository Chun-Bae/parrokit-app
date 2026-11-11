import 'package:flutter/material.dart';
import '../../data/constants/edit_strings.dart';
import '../providers/captioning_provider.dart';
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
          // 1. 컬렉션 (자동완성)
          Autocomplete<String>(
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim();
              if (query.isEmpty) return vm.allCollectionNames;
              return vm.allCollectionNames.where(
                (name) => name.toLowerCase().contains(query.toLowerCase()),
              );
            },
            onSelected: (selection) {
              vm.collectionNameCtl.text = selection;
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              if (controller.text != vm.collectionNameCtl.text) {
                controller.text = vm.collectionNameCtl.text;
              }
              controller.addListener(() {
                vm.collectionNameCtl.text = controller.text;
              });
              return _LinearInputField(
                label: EditStrings.collectionLabel,
                hint: EditStrings.collectionHint,
                controller: controller,
                focusNode: focusNode,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 280, minWidth: 240),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Text(option),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

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
    this.focusNode,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  State<_LinearInputField> createState() => _LinearInputFieldState();
}

class _LinearInputFieldState extends State<_LinearInputField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _LinearInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChanged);
    }
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
