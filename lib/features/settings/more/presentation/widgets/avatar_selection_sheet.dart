// lib/features/auth/presentation/widgets/avatar_selection_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/settings/more/data/avatar_presets.dart';

class AvatarSelectionSheet extends StatelessWidget {
  const AvatarSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '프로필 캐릭터 선택',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              itemCount: avatarPresets.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return GestureDetector(
                    onTap: () {
                      context.pop(''); // 빈 문자열로 리턴하여 제거를 알림
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.person_off_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final url = avatarPresets[index - 1];
                return GestureDetector(
                  onTap: () {
                    context.pop(url); // url 리턴
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipOval(
                      child: SvgPicture.network(
                        url,
                        fit: BoxFit.cover,
                        placeholderBuilder: (context) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
