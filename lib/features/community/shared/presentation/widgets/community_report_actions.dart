import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/shared/data/community_report_repository.dart';
import 'package:parrokit/features/community/shell/data/debug_fake_community.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';

/// 글·댓글 옵션 시트의 '신고'. 사유를 고르면 reports에 남긴다. 예전에는 누르자마자
/// "신고가 접수되었습니다." 토스트만 띄우고 아무것도 남기지 않았다(5차).
/// [commentId]가 없으면 글 신고다. [repository]는 테스트에서 바꿔 끼운다.
CommunityOptionAction buildCommunityReportAction({
  required BuildContext context,
  required String postId,
  String? commentId,
  required String targetAuthorId,
  CommunityReportRepository? repository,
}) {
  return CommunityOptionAction(
    label: '신고',
    icon: Icons.report_outlined,
    onTap: () async {
      final reason = await showReportReasonDialog(context);
      if (reason == null || !context.mounted) return;
      final reporterId = context.read<UserProvider?>()?.currentUser?.id;
      if (reporterId == null || reporterId.isEmpty) {
        showToast('로그인이 필요합니다.');
        return;
      }
      // 개발 빌드 전용 가짜 글은 서버에 쓰지 않는다.
      if (isFakePost(postId)) {
        showToast('신고가 접수되었어요. 운영자가 확인할게요.');
        return;
      }
      try {
        await (repository ?? CommunityReportRepository()).submit(
          reporterId: reporterId,
          postId: postId,
          commentId: commentId,
          targetAuthorId: targetAuthorId,
          reason: reason,
        );
        showToast('신고가 접수되었어요. 운영자가 확인할게요.');
      } catch (e, st) {
        AppLogger.e('신고 저장 실패', error: e, stackTrace: st);
        showToast(userErrorMessage(e,
            fallback: '신고하지 못했어요. 잠시 뒤 다시 시도해 주세요.'));
      }
    },
  );
}

/// 신고 사유 고르기. 취소하면 null.
Future<ReportReason?> showReportReasonDialog(BuildContext context) =>
    showDialog<ReportReason>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('신고 사유'),
        children: [
          for (final reason in ReportReason.values)
            SimpleDialogOption(
              key: ValueKey('report-reason-${reason.code}'),
              onPressed: () => Navigator.pop(dialogContext, reason),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(reason.label),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('취소'),
            ),
          ),
        ],
      ),
    );
