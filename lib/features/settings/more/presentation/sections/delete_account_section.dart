import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 회원탈퇴 섹션.
class DeleteAccountSection extends StatelessWidget {
  const DeleteAccountSection({super.key});

  Future<void> _confirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text('탈퇴하면 모든 데이터가 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '탈퇴',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<UserProvider>().deleteAccount();
      if (context.mounted) showToast('탈퇴가 완료되었습니다.');
    } catch (e) {
      if (context.mounted) showToast('탈퇴 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => _confirm(context),
        child: Text(
          '회원탈퇴',
          style: context.texts.labelMedium.copyWith(
              color:
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}
