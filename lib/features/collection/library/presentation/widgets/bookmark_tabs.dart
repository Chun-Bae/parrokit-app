import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';
import '../../domain/library_mode.dart';

/// [역할]
/// 라이브러리 상단의 탭 전환 위젯 (유형별 보기 / 태그로 보기).
///
/// 생김새는 앱 전역 세그먼트 컨트롤([AppSegmentedTabs])을 그대로 쓴다.
class BookmarkTabs extends StatelessWidget {
  const BookmarkTabs({super.key, required this.value, required this.onChanged});

  final LibraryTab value;
  final ValueChanged<LibraryTab> onChanged;

  static const _tabs = [LibraryTab.folder, LibraryTab.tag];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppSegmentedTabs(
        selectedIndex: _tabs.indexOf(value),
        onChanged: (index) => onChanged(_tabs[index]),
        segments: const [
          AppSegment(icon: Icons.folder_open_rounded, label: '유형별 보기'),
          AppSegment(icon: Icons.sell_outlined, label: '태그로 보기'),
        ],
      ),
    );
  }
}
