import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/share_my_sentence_sheet.dart';

void showCommunityWriteBottomSheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
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
                // 제목이 '커뮤니티 글쓰기'라 그 안의 첫 줄 '글쓰기'와 겹쳤다.
                // 누른 단추도 '글쓰기'여서 같은 말이 세 겹이었다(5차 494).
                // 이 시트가 하는 일은 무엇을 올릴지 고르는 것이다. 보관함의
                // '+' 시트('무엇을 추가할까요?')와 같은 꼴로 묻는다.
                '무엇을 올릴까요?',
                style: context.texts.headlineSmall
                    .copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              _CommunityWriteOption(
                icon: Icons.edit_rounded,
                iconColor: AppColors.communityBoardAccent,
                bgColor: AppColors.communityBoardAccentSoft,
                // 목록의 버튼·메뉴와 같은 말로(5차). 예전 '게시판 작성'.
                title: '글쓰기',
                subtitle: '자유롭게 이야기 나눠 보세요',
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.communityBoardWritePath);
                },
              ),
              const SizedBox(height: 12),
              // 커뮤니티에 문장 탭이 생겼으니 여기서도 고를 수 있어야 한다
              // (5차 341). 탭마다 단추가 다른데 이 시트만 셋이었다.
              _CommunityWriteOption(
                icon: Icons.format_quote_rounded,
                iconColor: AppColors.communityBoardAccent,
                bgColor: AppColors.communityBoardAccentSoft,
                title: '문장 공유하기',
                subtitle: '내 문장을 다른 사람과 나눠요',
                onTap: () {
                  Navigator.pop(context);
                  showShareMySentenceSheet(context);
                },
              ),
              const SizedBox(height: 12),
              _CommunityWriteOption(
                icon: Icons.live_help_rounded,
                iconColor: AppColors.communityQuestionAccent,
                bgColor: AppColors.communityQuestionAccentSoft,
                title: '질문하기',
                subtitle: '궁금한 것을 물어보세요',
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
                subtitle: '여러 사람 의견을 받아 보세요',
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
