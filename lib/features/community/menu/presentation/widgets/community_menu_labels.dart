import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class CommunityMenuCategoryLabel extends StatelessWidget {
  const CommunityMenuCategoryLabel({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Text(
        title,
        style: context.texts.labelMedium
            .copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class CommunityMenuSectionTitle extends StatelessWidget {
  const CommunityMenuSectionTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text(
        title,
        style: context.texts.bodyMedium
            .copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
