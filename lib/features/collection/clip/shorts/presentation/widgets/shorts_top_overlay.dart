// 쇼츠 영상 위 위쪽 줄: 진행 띠 → 클립 이름 → 태그.
//
// 전에는 이름이 어디에도 없어서 무엇을 보고 있는지 알 수 없었고(‘연습’을
// 눌러 플레이어로 가야 알았다), 태그 배지는 진행 띠와 따로 떠 있었다(5차).

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'progress_bar.dart';
import 'shorts_badge.dart';

class ShortsTopOverlay extends StatelessWidget {
  const ShortsTopOverlay({
    super.key,
    required this.index,
    required this.total,
    required this.title,
    required this.tagNames,
  });

  final int index;
  final int total;
  final String title;
  final List<String> tagNames;

  @override
  Widget build(BuildContext context) {
    // 영상 위를 눌러 멈추는 동작을 가리지 않는다. 전에는 배지가 탭을 먹었다.
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressBar(index: index, total: total),
            if (title.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: shortsTitleStyle(context),
                ),
              ),
            if (tagNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    for (final name in tagNames)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ShortsBadge(
                          label: name,
                          icon: Icons.star_border_rounded,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 영상 위에 얹는 클립 이름 글꼴. 밝은 장면에서도 읽히게 그림자를 겹친다
/// (자막과 같은 방식).
TextStyle shortsTitleStyle(BuildContext context) =>
    context.texts.titleMedium.copyWith(
      color: Colors.white,
      shadows: const [
        Shadow(blurRadius: 2, color: Colors.black87, offset: Offset(0, 1)),
        Shadow(blurRadius: 10, color: Colors.black54),
      ],
    );
