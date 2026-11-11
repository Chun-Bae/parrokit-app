import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class ContentStudioAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ContentStudioAppBar({
    super.key,
    required this.title,
    required this.coins,
    required this.onBack,
    this.backgroundColor,
    this.onToggleExpand,
    this.isExpanded = false,
  });

  final String title;
  final int coins;
  final VoidCallback onBack;
  final Color? backgroundColor;
  final VoidCallback? onToggleExpand;
  final bool isExpanded;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surface;
    final fg = theme.colorScheme.onSurface;

    return AppBar(
      title: Text(title),
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 10),
              Text(
                '🦜',
                style: context.texts.titleLarge,
              ),
              const SizedBox(width: 5),
              Text(
                '$coins',
                style: theme.textTheme.bodyMedium,
              ),
              if (onToggleExpand != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface,
                  ),
                  tooltip: isExpanded ? '옵션 닫기' : '옵션 열기',
                  onPressed: onToggleExpand,
                ),
              ] else ...[
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
