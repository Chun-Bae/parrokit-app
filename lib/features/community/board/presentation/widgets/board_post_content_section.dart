import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:shimmer/shimmer.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class BoardPostContentSection extends StatelessWidget {
  const BoardPostContentSection({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            post.title,
            style: context.texts.titleLarge.copyWith(height: 1.25),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            post.content.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '').trim(),
            style: context.texts.titleMedium
                .copyWith(height: 1.6, color: AppColors.textPrimary),
          ),
        ),
        if (post.hasImage && post.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: post.imageUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: colorScheme.surfaceContainerHigh,
                        highlightColor: colorScheme.surfaceContainer,
                        child: Container(color: colorScheme.surface),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.broken_image,
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: post.tags
                  .map(
                    (tag) => Text(
                      '#$tag',
                      style: context.texts.bodyLarge
                          .copyWith(color: AppColors.textDisabled),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
