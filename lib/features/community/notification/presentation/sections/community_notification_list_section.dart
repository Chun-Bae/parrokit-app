import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/community/notification/domain/entities/community_notification_item.dart';
import 'package:parrokit/features/community/notification/presentation/providers/community_notification_provider.dart';
import 'package:parrokit/features/community/notification/presentation/widgets/community_notification_empty_state.dart';
import 'package:parrokit/features/community/notification/presentation/widgets/community_notification_tile.dart';

class CommunityNotificationListSection extends StatelessWidget {
  final CommunityNotificationProvider provider;

  const CommunityNotificationListSection({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 빈 화면에서도 당겨서 새로 고칠 수 있게 둔다. 전에는 목록이 있을 때만
    // 당길 수 있어서, 못 불러왔을 때 다시 해 볼 길이 없었다(5차).
    if (provider.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: provider.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const CommunityNotificationEmptyState(),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: provider.notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = provider.notifications[index];
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.transparent,
            ),
            secondaryBackground: Container(
              color: Theme.of(context).colorScheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
            ),
            onDismissed: (_) async {
              await provider.deleteNotification(item.id);
              if (!context.mounted) return;
              if (provider.errorMessage == null) {
                showToast('알림을 지웠어요.');
              }
            },
            child: CommunityNotificationTile(
              item: item,
              onTap: () async {
                await provider.markAsRead(item.id);
                if (!context.mounted) return;
                context.push(_resolveRoutePath(item));
              },
            ),
          );
        },
      ),
    );
  }

  String _resolveRoutePath(CommunityNotificationItem item) {
    switch (item.boardType) {
      case 'question':
        return AppRoutes.communityQuestionViewPathOf(item.postId);
      case 'vote':
        return AppRoutes.communityVoteViewPathOf(item.postId);
      default:
        return AppRoutes.communityBoardViewPathOf(item.postId);
    }
  }
}
