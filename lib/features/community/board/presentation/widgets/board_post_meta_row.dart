import 'package:flutter/material.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class BoardPostMetaRow extends StatelessWidget {
  const BoardPostMetaRow({super.key, required this.post});

  final Post post;

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
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Row(
              children: [
                Text(
                  post.category,
                  style: context.texts.bodyLarge
                      .copyWith(color: context.tokens.textTertiary),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 20, color: context.tokens.textTertiary),
              ],
            ),
          ),
          const Spacer(),
          Icon(Icons.remove_red_eye_outlined,
              color: context.tokens.textDisabled, size: 24),
          const SizedBox(width: 6),
          Text(
            '${post.viewCount}',
            style: context.texts.bodyLarge
                .copyWith(color: context.tokens.textDisabled),
          ),
          // 공감 수는 아래 '공감' 버튼이 보여 준다. 여기에도 두면 같은 수가
          // 멀리 떨어진 두 곳에 있어서, 버튼을 눌렀을 때 바뀌는 곳이 화면
          // 밖일 수 있었다(5차).
        ],
      ),
    );
  }
}
