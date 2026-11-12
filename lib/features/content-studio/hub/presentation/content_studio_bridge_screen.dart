import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class ContentStudioBridgeScreen extends StatelessWidget {
  const ContentStudioBridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface =
        isDark ? context.tokens.surfaceContainer : colorScheme.surface;
    final border = context.tokens.dividerSubtle;
    final secondaryText = context.tokens.textSecondary;
    // 새 디자인: 세 줄이 카드처럼 생겼는데 눌러도 아무 일이 없었다. 줄을 누르면
    // 그 탭으로 바로 가고, 같은 말을 하던 부제와 '시작하기' 버튼은 숨긴다.
    final newDesign = AppConfig.newDesign;
    void openTab(int index) =>
        context.go('${AppRoutes.contentStudioHubPath}?tab=$index');

    // 뒤로가기를 다른 화면처럼 앱바에 둔다. 전에는 본문 안에 IconButton을
    // 넣어서, 다른 화면보다 오른쪽·아래로 16pt쯤 들어간 자리에 있었다.
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.dashboardPath),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.tokens.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: context.tokens.primary,
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
                      if (!newDesign) ...[
                        const SizedBox(height: 12),
                        Text(
                          '자막 편집, TTS, 영상 제작 흐름을 한 곳에서 이어서 작업하세요.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            color: secondaryText,
                          ),
                        ),
                      ],
                      SizedBox(height: newDesign ? 24 : 32),
                      _BridgeFeatureRow(
                        key: const ValueKey('studio-open-captioning'),
                        icon: Icons.subtitles_rounded,
                        title: '자막',
                        description: newDesign
                            ? '영상에 자막을 달아 클립으로 저장해요'
                            : '클립을 불러오고 제목, 태그, 세그먼트를 정리합니다.',
                        borderColor: border,
                        onTap: newDesign ? () => openTab(0) : null,
                      ),
                      const SizedBox(height: 12),
                      _BridgeFeatureRow(
                        key: const ValueKey('studio-open-tts'),
                        icon: Icons.graphic_eq_rounded,
                        title: 'TTS',
                        description: newDesign
                            ? '문장을 읽어 주는 음성을 만들어요'
                            : '대본 기반 음성 제작 흐름을 준비합니다.',
                        borderColor: border,
                        onTap: newDesign ? () => openTab(1) : null,
                      ),
                      const SizedBox(height: 12),
                      _BridgeFeatureRow(
                        key: const ValueKey('studio-open-video'),
                        icon: Icons.movie_creation_rounded,
                        title: 'Video',
                        description: newDesign
                            ? '대본으로 짧은 영상을 만들어요'
                            : '영상 제작 도구로 결과물을 확장합니다.',
                        borderColor: border,
                        onTap: newDesign ? () => openTab(2) : null,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (!newDesign)
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
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.borderColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color borderColor;

  /// 있으면 줄 전체를 누를 수 있고 오른쪽에 화살표가 붙는다.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final secondaryText = context.tokens.textSecondary;

    final row = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.tokens.primary, size: 22),
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
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: secondaryText),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: row,
      ),
    );
  }
}
