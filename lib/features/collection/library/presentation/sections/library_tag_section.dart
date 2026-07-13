// ============================================================================
// lib/features/_content/library/presentation/sections/library_tag_section.dart
// ============================================================================
//
// [역할]
// 라이브러리 화면의 "태그" 탭 섹션 (검색 + 칩 + 결과)
//
// [레이어]
// Presentation Layer > Sections
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/data/local/app_database.dart';
import '../widgets/clip_list_view.dart';

class LibraryTagSection extends StatelessWidget {
  const LibraryTagSection({
    super.key,
    required this.allTags,
    required this.selectedTags,
    required this.onTagSelected,
    required this.onTagDeleted,
    required this.onSelectAll,
    required this.onClearResult,
  });

  final List<Tag> allTags;
  final Set<String> selectedTags;
  final ValueChanged<Tag> onTagSelected;
  final ValueChanged<String> onTagDeleted;
  final VoidCallback onSelectAll;
  final VoidCallback onClearResult;

  Iterable<Tag> _optionsFor(String query) {
    final q = query.trim().toLowerCase();
    final base = q.isEmpty
        ? allTags
        : allTags.where((t) => t.name.toLowerCase().contains(q));
    return base.where((t) => !selectedTags.contains(t.name)).take(30);
  }

  @override
  Widget build(BuildContext context) {
    if (allTags.isEmpty) {
      return const Center(child: Text('등록된 태그가 없어요.'));
    }

    final names = selectedTags.toList().reversed.toList();

    // 드롭다운 컨트롤러는 build scope 안에서 처리 (Stateless)
    TextEditingController? acCtrl;
    FocusNode? acFocus;

    return CustomScrollView(
      slivers: [
        // 🔎 자동완성 검색 + 전체해제 버튼
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Autocomplete<Tag>(
                    displayStringForOption: (t) => t.name,
                    optionsBuilder: (text) => _optionsFor(text.text),
                    fieldViewBuilder:
                        (context, controller, focusNode, onUnfocus) {
                      acCtrl = controller;
                      acFocus = focusNode;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '태그 검색',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: (controller.text.isEmpty)
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: '검색어 지우기',
                                  onPressed: () {
                                    controller.clear();
                                    focusNode.requestFocus();
                                  },
                                ),
                          filled: true,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing
                                .sm, // 12, 8? original was 12, 8 at line 99?
                          ),
                        ),
                        // suffixIcon 갱신을 위해 setState 필요할 수 있으나,
                        // 여기서는 controller listener가 없으므로 타이핑 시 아이콘 갱신이 즉시 안 될 수 있음.
                        // Stateless에서는 한계가 있으나, TextField 자체 rebuild가 일어나면 갱신됨.
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 410,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 280, minWidth: 240),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm),
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1, thickness: 0.5),
                                itemBuilder: (context, index) {
                                  final t = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(t),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.md),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome,
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              t.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.fontFamily,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (t) {
                      onTagSelected(t);
                      acCtrl?.clear();
                      acFocus?.unfocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 전체 선택 (All)
                SizedBox(
                  height: 48,
                  width: 48,
                  child: OutlinedButton(
                    onPressed: onSelectAll,
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 선택 해제 (Cleaner)
                SizedBox(
                  height: 48,
                  width: 48,
                  child: OutlinedButton(
                    onPressed: selectedTags.isEmpty ? null : onClearResult,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.cleaning_services, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ⬇️ 선택된 태그들: 횡스크롤 한 줄
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 40,
              width: double.infinity,
              child: selectedTags.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          for (final name in names) ...[
                            FilterChip(
                              label: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontFamily,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              selected: true,
                              onSelected: (_) {},
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              selectedColor:
                                  Theme.of(context).colorScheme.primary,
                              checkmarkColor: Colors.white,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: AppColors.primary, width: 1),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                  horizontal: -2, vertical: -2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm),
                              deleteIcon: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                              onDeleted: () => onTagDeleted(name),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),

        // ⬇️ 결과 리스트
        Selector<TagFilterProvider, List<ClipItem>>(
          selector: (_, p) => p.items,
          shouldRebuild: (prev, next) {
            if (prev.length != next.length) return true;
            for (var i = 0; i < prev.length; i++) {
              if (prev[i].clip.id != next[i].clip.id) return true;
            }
            return false;
          },
          builder: (context, items, __) {
            return SliverMainAxisGroup(
              slivers: ClipListView(
                items: items,
                onOpen: (ci) {
                  context.push(
                    '${AppRoutes.clipsPath}/${AppRoutes.clipsPlayPath}?clipId=${ci.clip.id}',
                  );
                },
              ).buildSlivers(context),
            );
          },
        ),
      ],
    );
  }
}
