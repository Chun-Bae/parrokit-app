import 'package:flutter/material.dart';
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
              alignment: Alignment(-1 + (widget.selectedIndex * 1.0), 0),
              duration: _animationDuration,
              curve: Curves.easeInOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
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
                  title: 'TTS',
                  icon: Icons.graphic_eq_rounded,
                  isSelected: widget.selectedIndex == 1,
                  selectedText: selectedText,
                  unselectedText: unselectedText,
                  onTap: () => _handleTap(1),
                ),
                _StudioSwitchItem(
                  title: 'Video',
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
