import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'folder_card.dart';

class FolderGrid extends StatelessWidget {
  const FolderGrid({
    super.key,
    required this.sectionTitle,
    required this.items,
    required this.onTap,
    this.onLongPress,
    this.deleteMode = false,
    this.isGridView = true,
    this.onToggleView,
    this.onAdd,
  });

  final String sectionTitle;
  final List<String> items;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onLongPress;
  final bool deleteMode;
  final bool isGridView;
  final VoidCallback? onToggleView;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: buildSlivers(context));
  }

  /// 다른 스크롤 영역(예: 상위 화면의 [CustomScrollView])에 이어붙일 수
  /// 있도록 슬리버 목록만 뽑아낸 것. [build]도 이 목록을 그대로 사용한다.
  List<Widget> buildSlivers(BuildContext context) {
    final int extraCount = (onAdd != null && !deleteMode) ? 1 : 0;
    final int totalCount = items.length + extraCount;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sectionTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              if (onToggleView != null)
                IconButton(
                  onPressed: onToggleView,
                  icon: Icon(isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
      if (totalCount == 0)
        const SliverFillRemaining(
          child: Center(child: Text('아직 등록된 항목이 없어요.')),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          sliver: isGridView
              ? SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildCard(i),
                    childCount: totalCount,
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: SizedBox(
                        height: 72,
                        child: _buildCard(i),
                      ),
                    ),
                    childCount: totalCount,
                  ),
                ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _buildCard(int i) {
    if (i == items.length) {
      return FolderCard(
        name: '$sectionTitle 추가',
        onTap: onAdd!,
        isGridView: isGridView,
        isAddCard: true,
      );
    }

    final isSpecial = i == 0 && (sectionTitle == '그룹' || sectionTitle == '컬렉션');
    return FolderCard(
      name: items[i],
      onTap: () => onTap(i),
      onLongPress:
          (onLongPress == null || isSpecial) ? null : () => onLongPress!(i),
      deleteMode: deleteMode && !isSpecial,
      isGridView: isGridView,
      isSpecial: isSpecial,
      isGroup: sectionTitle == '그룹',
    );
  }
}
