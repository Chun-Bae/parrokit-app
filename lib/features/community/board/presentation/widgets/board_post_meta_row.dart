import 'package:flutter/material.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BoardPostMetaRow extends StatelessWidget {
  const BoardPostMetaRow({
    super.key,
    required this.post,
    required this.likeMetaColor,
    required this.likeIconColor,
  });

  final Post post;
  final Color likeMetaColor;
  final Color likeIconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Text(
                  post.category,
                  style: context.texts.bodyLarge
                      .copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textTertiary),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.remove_red_eye_outlined,
              color: AppColors.textDisabled, size: 24),
          const SizedBox(width: 6),
          Text(
            '${post.viewCount}',
            style:
                context.texts.bodyLarge.copyWith(color: AppColors.textDisabled),
          ),
          const SizedBox(width: 18),
          Icon(Icons.thumb_up_outlined, color: likeIconColor, size: 24),
          const SizedBox(width: 6),
          Text(
            '${post.likeCount}',
            style: context.texts.bodyLarge.copyWith(color: likeMetaColor),
          ),
        ],
      ),
    );
  }
}
