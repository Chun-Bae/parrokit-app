import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/community/notification/presentation/providers/community_notification_provider.dart';
import 'package:parrokit/features/community/notification/presentation/sections/community_notification_list_section.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class CommunityNotificationScreen extends StatefulWidget {
  const CommunityNotificationScreen({super.key});

  @override
  State<CommunityNotificationScreen> createState() =>
      _CommunityNotificationScreenState();
}

class _CommunityNotificationScreenState
    extends State<CommunityNotificationScreen> {
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
          backgroundColor: context.tokens.surface,
          appBar: AppBar(
            backgroundColor: context.tokens.surface,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 24,
                color: context.tokens.textPrimary,
              ),
            ),
            title: Text(
              '알림',
              style: context.texts.headlineMedium
                  .copyWith(color: context.tokens.textPrimary),
            ),
            actions: [
              // 알림 설정으로 바로 간다(5차). 메뉴(≡)에도 같은 줄이 있다.
              IconButton(
                key: const ValueKey('open-notification-settings'),
                tooltip: '알림 설정',
                onPressed: () =>
                    context.push(AppRoutes.communityNotificationSettingsPath),
                icon: Icon(Icons.settings_outlined,
                    size: 24, color: context.tokens.textPrimary),
              ),
              // 알림이 없어도 연다. 전에는 흐리게 꺼져 있어서, 목록을 못
              // 불러왔을 때 '새로 고침'에 갈 길이 아예 없었다(5차).
              IconButton(
                key: const ValueKey('open-notification-actions'),
                tooltip: '알림 메뉴',
                onPressed: () =>
                    _showNotificationActionsSheet(context, provider),
                icon: Icon(Icons.more_vert_rounded,
                    size: 24, color: context.tokens.textPrimary),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: context.tokens.disabled),
            ),
          ),
          body: Column(
            children: [
              _NotificationSummaryBar(provider: provider),
              if (provider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: context.tokens.danger.withValues(alpha: 0.08),
                  child: Text(
                    provider.errorMessage!,
                    style: context.texts.bodyMedium
                        .copyWith(color: context.tokens.danger),
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

  /// 알림을 모두 지우기 전에 한 번 묻는다.
  ///
  /// 전에는 메뉴에서 '모두 지우기'를 누르는 순간 전부 사라졌다. 되돌릴 수
  /// 없는데 확인이 없었다. 글·댓글 지우기와 같은 말과 모양으로 묻는다(5차).
  Future<void> _confirmDeleteAll(
    BuildContext context,
    CommunityNotificationProvider provider,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('알림 모두 지우기',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('알림을 모두 지울까요?\n지우면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-all-notifications'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('모두 지우기',
                style: TextStyle(
                    color: context.tokens.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.deleteAllNotifications();
    if (!context.mounted) return;
    if (provider.errorMessage == null) {
      showToast('알림을 모두 지웠어요.');
    }
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
          // 다 읽었으면 할 일이 없다. 전에는 눌러도 조용히 닫히기만 했다(5차).
          enabled: provider.unreadCount > 0,
          onTap:
              provider.unreadCount == 0 ? () async {} : provider.markAllAsRead,
        ),
        CommunityOptionAction(
          label: '모두 지우기',
          isDestructive: true,
          enabled: provider.hasNotifications,
          onTap: provider.hasNotifications
              ? () => _confirmDeleteAll(context, provider)
              : () async {},
        ),
        CommunityOptionAction(
          label: '새로 고침',
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
        border: Border(
          bottom: BorderSide(color: context.tokens.disabled, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            '읽지 않은 알림 ${provider.unreadCount}개',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '전체 ${provider.notifications.length}개',
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
