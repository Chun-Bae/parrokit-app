import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/community/block/presentation/providers/block_provider.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

CommunityOptionAction buildCommunityBlockAction({
  required BuildContext context,
  required String targetUid,
  required String? targetDisplayName,
}) {
  return CommunityOptionAction(
    label: '차단',
    isDestructive: true,
    onTap: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final displayName = (targetDisplayName ?? '').trim();
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: const Text('사용자 차단'),
            content: Text(
              displayName.isEmpty
                  ? '정말 이 사용자를 차단하시겠습니까?\n차단한 사용자의 글과 댓글이 더 이상 보이지 않습니다.'
                  : '$displayName 님을 차단하시겠습니까?\n차단한 사용자의 글과 댓글이 더 이상 보이지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  '차단',
                  style: TextStyle(
                      color: context.tokens.danger,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !context.mounted) return;

      final currentUser = context.read<UserProvider>().currentUser;
      if (currentUser == null) return;

      final success =
          await context.read<BlockProvider>().blockUserByUid(targetUid);
      if (!context.mounted) return;

      if (!success) {
        showToast(context.read<BlockProvider>().errorMessage ?? '차단에 실패했어요.');
        return;
      }

      showToast('차단했어요.');
      context.go(AppRoutes.communityPath);
    },
  );
}
