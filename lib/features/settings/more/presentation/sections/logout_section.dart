import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 로그아웃 섹션.
class LogoutSection extends StatelessWidget {
  const LogoutSection({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final userProvider = context.read<UserProvider>();
    final communityProvider = context.read<CommunityProvider>();
    final clipProvider = context.read<ClipProvider>();

    try {
      // 1. 커뮤니티 전역 상태(글 목록, 스크랩, 조회수 등) 초기화
      communityProvider.clear();

      // 2. 계정 소유 원격 클립 로컬 캐시 정리 (signOut 전에 uid가 필요)
      await clipProvider.migrationService.clearCachedFilesForCurrentAccount();

      // 3. 실제 인증 로그아웃 처리
      await userProvider.signOut();

      // 4. 이전 계정 기준으로 남아있는 저장공간 사용량 숫자 갱신
      // (refreshStorageUsage는 자체적으로 notifyListeners를 호출하지 않으므로
      // resetTransientUiState보다 먼저 실행해 한 번의 갱신으로 반영합니다)
      await clipProvider.refreshStorageUsage();

      // 5. 이전 계정 세션에서 멈춰있을 수 있는 선택/진행 상태 초기화
      clipProvider.resetTransientUiState();

      if (context.mounted) {
        showToast('로그아웃되었습니다.');
        context.go('${AppRoutes.authPath}/${AppRoutes.signInPath}');
      }
    } catch (e) {
      if (context.mounted) showToast('로그아웃 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _confirmLogout(context),
      child: Text(
        '로그아웃',
        style: context.texts.labelMedium.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}
