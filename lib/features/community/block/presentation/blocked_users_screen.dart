import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/block/presentation/providers/block_provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:provider/provider.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final TextEditingController _identifierController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BlockProvider>().loadBlockedUsers();
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _handleBlock() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;

    final currentUser = context.read<UserProvider>().currentUser;
    final currentDisplayName = currentUser?.displayName?.trim();
    if (currentDisplayName != null && currentDisplayName.isNotEmpty && currentDisplayName == identifier) {
      showToast('본인 닉네임이에요.');
      return;
    }

    final blockProvider = context.read<BlockProvider>();
    final success = await blockProvider.blockUserByDisplayName(identifier);
    if (!mounted) return;

    if (!success) {
      showToast(blockProvider.errorMessage ?? '차단에 실패했어요.');
      return;
    }

    await context.read<CommunityProvider>().fetchPosts(refresh: true);
    if (!mounted) return;

    _identifierController.clear();
    showToast('차단했어요.');
  }

  Future<void> _handleUnblock(String blockedUserId) async {
    final blockProvider = context.read<BlockProvider>();
    final success = await blockProvider.unblockUser(blockedUserId);
    if (!mounted) return;

    if (!success) {
      showToast(blockProvider.errorMessage ?? '차단 해제에 실패했어요.');
      return;
    }

    await context.read<CommunityProvider>().fetchPosts(refresh: true);
    if (!mounted) return;

    showToast('차단을 해제했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final blockProvider = context.watch<BlockProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('차단 사용자 관리'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '닉네임을 입력해 차단할 수 있어요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _identifierController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                    ),
                    onSubmitted: (_) => _handleBlock(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // 빈 칸에서 눌러도 아무 반응이 없었다(5차). 닉네임을 넣어야 켜진다.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _identifierController,
                  builder: (context, value, _) => FilledButton(
                    key: const ValueKey('block-submit'),
                    onPressed:
                        blockProvider.isLoading || value.text.trim().isEmpty
                            ? null
                            : _handleBlock,
                    child: blockProvider.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('차단'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '차단 목록',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: blockProvider.isLoading && blockProvider.blockedUsers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : blockProvider.blockedUsers.isEmpty
                      // 다른 목록 화면과 같은 빈 화면 모양을 쓴다.
                      ? const AppEmptyState(
                          icon: Icons.block_rounded,
                          title: '아직 차단한 사용자가 없어요.',
                          description: '차단하면 그 사람의 글과 댓글이 보이지 않아요.',
                        )
                      : RefreshIndicator(
                          onRefresh: () => context.read<BlockProvider>().loadBlockedUsers(),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: blockProvider.blockedUsers.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = blockProvider.blockedUsers[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                  backgroundImage: user.photoUrl != null &&
                                          user.photoUrl!.isNotEmpty
                                      ? NetworkImage(user.photoUrl!)
                                      : null,
                                  child: user.photoUrl == null || user.photoUrl!.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(user.displayName ?? '이름 없음'),
                                trailing: TextButton(
                                  onPressed: blockProvider.isLoading
                                      ? null
                                      : () => _handleUnblock(user.id),
                                  child: const Text('해제'),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
