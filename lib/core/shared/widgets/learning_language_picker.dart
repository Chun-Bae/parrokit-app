import 'package:flutter/material.dart';

import 'package:parrokit/core/content/learning_languages.dart';

class LearningLanguagePicker extends StatelessWidget {
  const LearningLanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool compact;

  Future<void> openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LanguagePickerSheet(selected: value),
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final language = learningLanguageFor(value);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: compact
          ? colors.surface
          : colors.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => openPicker(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 9 : 12,
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 9),
              if (!compact)
                Text(
                  '학습 언어',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (!compact) const Spacer(),
              Text(
                language.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.selected});

  final String selected;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late final TextEditingController searchController;
  String query = '';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController()
      ..addListener(() {
        if (mounted) setState(() => query = searchController.text.trim());
      });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = query.toLowerCase();
    final languages = availableLearningLanguages
        .where((language) =>
            normalized.isEmpty ||
            language.searchTerms.toLowerCase().contains(normalized))
        .toList(growable: false);
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          2,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '학습 언어',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              '앵무새가 말하고 기록할 언어를 선택하세요.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '언어 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색어 지우기',
                        onPressed: searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.48,
              ),
              child: languages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('검색 결과가 없어요.')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: languages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 5),
                      itemBuilder: (context, index) {
                        final language = languages[index];
                        final selected = language.label == widget.selected;
                        return ListTile(
                          onTap: () => Navigator.pop(context, language.label),
                          tileColor: selected
                              ? colors.primaryContainer.withValues(alpha: 0.65)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          leading: Text(language.flag,
                              style: const TextStyle(fontSize: 25)),
                          title: Text(
                            language.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(language.nativeLabel),
                          trailing: selected
                              ? Icon(Icons.check_circle_rounded,
                                  color: colors.primary)
                              : const Icon(Icons.chevron_right_rounded),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 7),
                Text(
                  '새 언어는 이 목록에 계속 추가할 수 있어요.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
