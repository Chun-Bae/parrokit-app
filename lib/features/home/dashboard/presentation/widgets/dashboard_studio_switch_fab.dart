import 'package:flutter/material.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';

class DashboardStudioSwitchFab extends StatefulWidget {
  const DashboardStudioSwitchFab({
    super.key,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;

  @override
  State<DashboardStudioSwitchFab> createState() =>
      _DashboardStudioSwitchFabState();
}

class _DashboardStudioSwitchFabState extends State<DashboardStudioSwitchFab> {
  static const _animationDuration = Duration(milliseconds: 240);

  /// 지금 보이는 칸 수. 영상 탭은 꺼져 있을 수 있다.
  int get _tabCount => kVideoStudioEnabled ? 3 : 2;

  void _handleTap(int index) {
    widget.onSelectedIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface =
        isDark ? context.tokens.surfaceContainer : context.tokens.surface;
    final border = context.tokens.dividerSubtle;
    // 앱 메인 탭바와 같은 선택 표시를 쓴다. 자리와 역할이 같아서다.
    final selectedBg = context.tokens.primary
        .withValues(alpha: AppTheme.bottomNavSelectionOpacity);
    final selectedText = context.tokens.primary;
    final unselectedText = context.tokens.textSecondary;

    return AnimatedContainer(
      duration: _animationDuration,
      curve: Curves.easeInOutCubic,
      height: 64,
      width: 312,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            AnimatedAlign(
              // 칸 수를 세서 자리를 잡는다. 전에는 늘 세 칸으로 보고 1/3
              // 너비에 세 칸 위치를 썼다. 영상 탭을 숨기면 칸은 둘인데
              // 선택 표시만 가운데 빈 곳에 떠 있었다(5차).
              alignment: Alignment(
                  studioSwitchIndicatorX(
                      count: _tabCount, index: widget.selectedIndex),
                  0),
              duration: _animationDuration,
              curve: Curves.easeInOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / _tabCount,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedBg,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _StudioSwitchItem(
                  title: '자막',
                  icon: Icons.subtitles_rounded,
                  isSelected: widget.selectedIndex == 0,
                  selectedText: selectedText,
                  unselectedText: unselectedText,
                  onTap: () => _handleTap(0),
                ),
                _StudioSwitchItem(
                  title: '음성 만들기',
                  icon: Icons.graphic_eq_rounded,
                  isSelected: widget.selectedIndex == 1,
                  selectedText: selectedText,
                  unselectedText: unselectedText,
                  onTap: () => _handleTap(1),
                ),
                if (kVideoStudioEnabled)
                  _StudioSwitchItem(
                    // 옆 칸 '자막'처럼 한글로(5차). 예전 'Video'.
                    title: '영상',
                    icon: Icons.movie_creation_rounded,
                    isSelected: widget.selectedIndex == 2,
                    selectedText: selectedText,
                    unselectedText: unselectedText,
                    onTap: () => _handleTap(2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioSwitchItem extends StatelessWidget {
  const _StudioSwitchItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.selectedText,
    required this.unselectedText,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final Color selectedText;
  final Color unselectedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            scale: isSelected ? 1.04 : 1.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isSelected ? 1 : 0.78,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? selectedText : unselectedText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: context.texts.labelMedium.copyWith(
                        color: isSelected ? selectedText : unselectedText,
                        letterSpacing: 0.1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 선택 표시를 둘 가로 위치(-1 왼쪽 끝 ~ 1 오른쪽 끝).
///
/// 칸이 하나뿐이면 가운데, 그 밖에는 칸 수에 맞춰 고르게 나눈다.
double studioSwitchIndicatorX({required int count, required int index}) {
  if (count <= 1) return 0;
  final clamped = index.clamp(0, count - 1);
  return -1 + clamped * (2 / (count - 1));
}
