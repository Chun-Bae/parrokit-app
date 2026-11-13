import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    // 세 줄이 카드처럼 생겼는데 눌러도 아무 일이 없었다. 줄을 누르면 그 탭으로
    // 바로 간다. 같은 말을 하던 부제와 '시작하기' 버튼은 없앴다(4차).
    //
    // go로 열면 쌓인 화면(보관함 등)이 사라져서, 허브에서 나가면 늘 홈으로
    // 갔다(4차 발견). 이 첫 화면만 허브로 바꿔 끼워, 허브에서 나가면 들어오기
    // 전 화면으로 돌아간다(5차).
    void openTab(int index) =>
        context.pushReplacement('${AppRoutes.contentStudioHubPath}?tab=$index');

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
                      const SizedBox(height: 24),
                      _BridgeFeatureRow(
                        key: const ValueKey('studio-open-captioning'),
                        icon: Icons.subtitles_rounded,
                        title: '자막',
                        description: '영상에 자막을 달아 클립으로 저장해요',
                        borderColor: border,
                        onTap: () => openTab(0),
                      ),
                      const SizedBox(height: 12),
                      _BridgeFeatureRow(
                        key: const ValueKey('studio-open-tts'),
                        icon: Icons.graphic_eq_rounded,
                        title: 'TTS',
                        description: '문장을 읽어 주는 음성을 만들어요',
                        borderColor: border,
                        onTap: () => openTab(1),
                      ),
                      const SizedBox(height: 12),
                      _BridgeFeatureRow(
                        key: const ValueKey('studio-open-video'),
                        icon: Icons.movie_creation_rounded,
                        title: 'Video',
                        description: '대본으로 짧은 영상을 만들어요',
                        borderColor: border,
                        onTap: () => openTab(2),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
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
