import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'bookmark_tab.dart';
import '../../domain/library_mode.dart';

/// [역할]
/// 라이브러리 상단의 탭 전환 위젯 (유형별 보기 / 태그로 보기).
///
/// [LibraryTab] 열거형을 사용하여 현재 선택된 탭을 표시하고 변경 이벤트를 알립니다.
/// iOS SegmentedControl과 유사한 애니메이션 효과를 제공합니다.
class BookmarkTabs extends StatelessWidget {
  const BookmarkTabs({super.key, required this.value, required this.onChanged});

  final LibraryTab value;
  final ValueChanged<LibraryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFolder = value == LibraryTab.folder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
          border: Border.all(color: cs.outlineVariant, width: 0.8),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment:
                  isFolder ? Alignment.centerLeft : Alignment.centerRight,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Container(
                width: (MediaQuery.of(context).size.width - 12 * 2 - 8 * 2) / 2,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: cs.primary.withValues(alpha: 0.5), width: 0.8),
                ),
              ),
            ),
            Row(children: [
              Expanded(
                child: BookmarkTab(
                  icon: Icons.folder_open_rounded,
                  label: '유형별 보기',
                  active: isFolder,
                  onTap: () => onChanged(LibraryTab.folder),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BookmarkTab(
                  icon: Icons.sell_outlined,
                  label: '태그로 보기',
                  active: !isFolder,
                  onTap: () => onChanged(LibraryTab.tag),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
