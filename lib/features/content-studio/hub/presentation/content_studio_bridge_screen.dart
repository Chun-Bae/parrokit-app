import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';

class ContentStudioBridgeScreen extends StatelessWidget {
  const ContentStudioBridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface =
        isDark ? AppColors.surfaceContainerDark : colorScheme.surface;
    final border =
        isDark ? AppColors.dividerSubtleDark : AppColors.dividerSubtle;
    final secondaryText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.dashboardPath),
                        icon: const Icon(Icons.arrow_back_rounded),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '콘텐츠 제작',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '자막 편집, TTS, 영상 제작 흐름을 한 곳에서 이어서 작업하세요.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.45,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _BridgeFeatureRow(
                        icon: Icons.subtitles_rounded,
                        title: '자막',
                        description: '클립을 불러오고 제목, 태그, 세그먼트를 정리합니다.',
                        borderColor: border,
                      ),
                      const SizedBox(height: 12),
                      _BridgeFeatureRow(
                        icon: Icons.graphic_eq_rounded,
                        title: 'TTS',
                        description: '대본 기반 음성 제작 흐름을 준비합니다.',
                        borderColor: border,
                      ),
                      const SizedBox(height: 12),
                      _BridgeFeatureRow(
                        icon: Icons.movie_creation_rounded,
                        title: 'Video',
                        description: '영상 제작 도구로 결과물을 확장합니다.',
                        borderColor: border,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.contentStudioHubPath),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('시작하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BridgeFeatureRow extends StatelessWidget {
  const _BridgeFeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.borderColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final secondaryText = theme.brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
