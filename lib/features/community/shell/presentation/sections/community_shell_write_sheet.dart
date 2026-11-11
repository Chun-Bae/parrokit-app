import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

void showCommunityWriteBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '커뮤니티 글쓰기',
                style: context.texts.headlineSmall
                    .copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              _CommunityWriteOption(
                icon: Icons.edit_rounded,
                iconColor: AppColors.communityBoardAccent,
                bgColor: AppColors.communityBoardAccentSoft,
                title: '게시판 작성',
                subtitle: '자유롭게 대화해보세요',
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.communityBoardWritePath);
                },
              ),
              const SizedBox(height: 12),
              _CommunityWriteOption(
                icon: Icons.live_help_rounded,
                iconColor: AppColors.communityQuestionAccent,
                bgColor: AppColors.communityQuestionAccentSoft,
                title: '질문하기',
                subtitle: '모르는 지식을 습득해보세요',
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.communityQuestionWritePath);
                },
              ),
              const SizedBox(height: 12),
              _CommunityWriteOption(
                icon: Icons.how_to_vote_rounded,
                iconColor: AppColors.communityVoteAccent,
                bgColor: AppColors.communityVoteAccentSoft,
                title: '투표 만들기',
                subtitle: '투표를 진행하여 다양한 의견을 받아보세요',
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.communityVoteWritePath);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CommunityWriteOption extends StatelessWidget {
  const _CommunityWriteOption({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.texts.titleLarge
                          .copyWith(color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: context.texts.bodyMedium
                          .copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: colorScheme.onSurfaceVariant, size: 28),
          ],
        ),
      ),
    );
  }
}
