import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/community/notification/presentation/providers/community_notification_provider.dart';
import 'package:parrokit/features/community/notification/presentation/sections/community_notification_list_section.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';

class CommunityNotificationScreen extends StatefulWidget {
  const CommunityNotificationScreen({super.key});

  @override
  State<CommunityNotificationScreen> createState() =>
      _CommunityNotificationScreenState();
}

class _CommunityNotificationScreenState extends State<CommunityNotificationScreen> {
  CommunityNotificationProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProvider = context.read<CommunityNotificationProvider>();
    if (_provider == nextProvider) {
      return;
    }

    _provider = nextProvider;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider?.activate();
    });
  }

  @override
  void dispose() {
    _provider?.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityNotificationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 24,
                color: Colors.black,
              ),
            ),
            title: const Text(
              '알림',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                onPressed: provider.hasNotifications
                    ? () => _showNotificationActionsSheet(context, provider)
                    : null,
                icon: const Icon(Icons.more_vert_rounded, size: 24, color: Colors.black87),
              ),
              const SizedBox(width: 4),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.disabled),
            ),
          ),
          body: Column(
            children: [
              _NotificationSummaryBar(provider: provider),
              if (provider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.danger.withValues(alpha: 0.08),
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: CommunityNotificationListSection(
                  provider: provider,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showNotificationActionsSheet(
    BuildContext context,
    CommunityNotificationProvider provider,
  ) async {
    await showCommunityOptionsSheet(
      context: context,
      title: '알림 메뉴',
      actions: [
        CommunityOptionAction(
          label: '모두 읽음',
          icon: Icons.done_all_rounded,
          onTap: provider.unreadCount == 0 ? () async {} : provider.markAllAsRead,
        ),
        CommunityOptionAction(
          label: '모두 지우기',
          icon: Icons.delete_sweep_outlined,
          isDestructive: true,
          onTap: provider.hasNotifications
              ? () async {
                  await provider.deleteAllNotifications();
                  if (!context.mounted) return;
                  if (provider.errorMessage == null) {
                    showToast('알림을 모두 삭제했습니다.');
                  }
                }
              : () async {},
        ),
        CommunityOptionAction(
          label: '새로 고침',
          icon: Icons.refresh_rounded,
          onTap: provider.refresh,
        ),
      ],
    );
  }
}

class _NotificationSummaryBar extends StatelessWidget {
  const _NotificationSummaryBar({
    required this.provider,
  });

  final CommunityNotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.disabled, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '읽지 않은 알림 ${provider.unreadCount}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '전체 ${provider.notifications.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
