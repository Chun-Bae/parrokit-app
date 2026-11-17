import 'package:parrokit/features/collection/shared/drive_disconnect.dart';
// ============================================================================
// lib/features/settings/more/presentation/sections/remote_storage_section.dart
// ============================================================================
//
// [역할]
// 서버와 개인 Cloud의 원격 저장 상태를 보여주는 섹션.
// ============================================================================

import 'package:parrokit/core/shared/utils/format_bytes.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/collection/shared/storage_segment_bar.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/paywall_presenter.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

/// 로컬·서버·Google Drive 저장 용량과 Drive 연동 버튼. 더보기 데이터 카드의
/// "저장 용량 · Google Drive" 줄을 누르면 시트로 열린다.
class RemoteStorageDetails extends StatefulWidget {
  const RemoteStorageDetails({super.key, this.presenter});

  /// 테스트에서 구독 화면 대신 쓸 것. 비우면 빌드에 맞는 것을 고른다.
  final PaywallPresenter? presenter;

  @override
  State<RemoteStorageDetails> createState() => _RemoteStorageDetailsState();
}

class _RemoteStorageDetailsState extends State<RemoteStorageDetails> {
  Widget _buildUsageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String usageText,
    required Color color,
    double? progress,
    Widget? action,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                ),
              ),
              Text(
                usageText,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }

  Widget _buildDriveUsageCard(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final driveUsed = clipProvider.googleDriveUsedBytes;
    final parrokitUsed = clipProvider.cloudStorageUsedBytes;
    final cloudQuota = clipProvider.cloudStorageQuotaBytes;
    final hasQuota = cloudQuota != null && cloudQuota > 0;
    final isBusy = clipProvider.isGoogleDriveLinking;
    final otherUsed = math.max(driveUsed - parrokitUsed, 0);
    final remaining = hasQuota ? math.max(cloudQuota - driveUsed, 0) : 0;

    final segments = hasQuota
        ? <StorageSegment>[
            StorageSegment(
              value: otherUsed,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            StorageSegment(
              value: parrokitUsed,
              color: Theme.of(context).colorScheme.primary,
            ),
            StorageSegment(
              value: remaining,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ]
        : <StorageSegment>[
            StorageSegment(
              value: otherUsed,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            StorageSegment(
              value: parrokitUsed,
              color: Theme.of(context).colorScheme.primary,
            ),
          ];

    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.drive_folder_upload_rounded,
                size: 18,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Google Drive (더 쓰지 않아요)',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                ),
              ),
              TextButton(
                key: const ValueKey('disconnect-google-drive'),
                onPressed: isBusy
                    ? null
                    : () => confirmAndDisconnectGoogleDrive(context),
                child: const Text(driveDisconnectConfirmLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StorageSegmentBar(segments: segments),
          const SizedBox(height: 8),
          Text(
            hasQuota
                ? '여기 있던 클립은 연동을 해제하면 기기로 옮겨요. Drive 전체에서 Parrokit 폴더 몫만 보여 줘요.'
                : '여기 있던 클립은 연동을 해제하면 기기로 옮겨요. Drive 전체 사용량은 못 가져와 Parrokit 폴더 몫만 보여 줘요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendChip(
                context,
                label: 'Parrokit ${formatBytes(parrokitUsed)}',
                color: cs.primary,
              ),
              _buildLegendChip(
                context,
                label: '기타 파일 ${formatBytes(otherUsed)}',
                color: cs.surfaceContainerHigh,
              ),
              if (hasQuota)
                _buildLegendChip(
                  context,
                  label: '남은 공간 ${formatBytes(remaining)}',
                  color: cs.surfaceContainerHighest,
                ),
            ],
          ),
          // 가득 참 경고는 뺐다(5차). 이제 Drive에 새로 올리지 않으므로
          // '새 클립을 올릴 수 없어요'는 맞지 않는 말이다.
        ],
      ),
    );
  }

  Widget _buildLegendChip(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final subscription = context.watch<SubscriptionProvider>();
    final localUsed = clipProvider.localStorageUsedBytes;
    // 서버가 센 값이 있으면 그것을 쓴다. 앱이 기기 목록을 더한 값은
    // 기기마다 달라서 한도를 말할 근거가 못 된다(5차).
    final serverUsed =
        subscription.storageUsedBytes ?? clipProvider.serverStorageUsedBytes;
    final serverTotal = serverStorageQuotaBytes(subscription.tier);
    final serverProgress =
        serverTotal == 0 ? 0.0 : (serverUsed / serverTotal).clamp(0.0, 1.0);
    return Column(
      children: [
        _buildUsageCard(
          context,
          icon: Icons.phone_android_rounded,
          title: '기기',
          subtitle: '이 기기에 있어 오프라인에서도 열 수 있는 파일',
          usageText: formatBytes(localUsed),
          color: Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildUsageCard(
          context,
          icon: Icons.cloud_queue_rounded,
          title: '서버',
          subtitle: serverStorageSubtitle(subscription.tier),
          usageText: serverTotal == 0
              ? formatBytes(serverUsed)
              : '${formatBytes(serverUsed)} / ${formatBytes(serverTotal)}',
          // secondary(primarySoft)는 라이트의 흰 카드 위에서 아이콘이 거의
          // 안 보였다. 막대와 아이콘 모두 브랜드 파랑으로 맞춘다.
          color: Theme.of(context).colorScheme.primary,
          // 무료는 서버에 담을 곳이 0이라 채울 수 없는 막대였다(5차 449).
          // 0 / 0을 그린 빈 막대는 '아직 안 찼다'로 읽혀서 오히려 거짓말이다.
          progress: serverTotal == 0 ? null : serverProgress,
          // '구독하면 백업돼요'라고만 하고 갈 길이 없었다(5차 449).
          action: serverTotal == 0
              ? TextButton(
                  key: const ValueKey('storage-open-subscription'),
                  onPressed: () =>
                      (widget.presenter ?? resolvePaywallPresenter())
                          .show(context),
                  child: const Text(subscriptionOpenButtonLabel),
                )
              : null,
        ),
        // Google Drive 저장은 더 쓰지 않는다(5차). 이미 연동한 사람에게만
        // 남은 파일과 '연동 해제'를 보여 주고, 연동하지 않은 사람에게는
        // 아예 보이지 않는다.
        if (context.watch<ClipProvider>().hasGoogleDriveLinked) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildDriveUsageCard(context),
        ],
      ],
    );
  }
}
