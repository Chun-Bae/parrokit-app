// ============================================================================
// lib/features/settings/more/presentation/sections/remote_storage_section.dart
// ============================================================================
//
// [역할]
// 서버와 개인 Cloud의 원격 저장 상태를 보여주는 섹션.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import '../widgets/card_container.dart';
import '../widgets/section_title.dart';

class RemoteStorageSection extends StatefulWidget {
  const RemoteStorageSection({super.key});

  @override
  State<RemoteStorageSection> createState() => _RemoteStorageSectionState();
}

class _RemoteStorageSectionState extends State<RemoteStorageSection> {
  bool _isExpanded = true;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  Widget _buildToggle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '저장 용량',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                  ),
                ),
                Text(
                  _isExpanded ? '접기' : '펼치기',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String usageText,
    required Color color,
    double? progress,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(999),
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
        ],
      ),
    );
  }

  Widget _buildSegmentedBar(
    BuildContext context, {
    required List<_StorageSegment> segments,
  }) {
    final cs = Theme.of(context).colorScheme;
    final visibleSegments =
        segments.where((segment) => segment.value > 0).toList();
    final effectiveSegments = visibleSegments.isEmpty
        ? [
            _StorageSegment(
              value: 1,
              color: cs.surfaceContainerHigh,
            ),
          ]
        : visibleSegments;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Row(
          children: effectiveSegments
              .map(
                (segment) => Expanded(
                  flex: math.max(segment.value, 1),
                  child: Container(color: segment.color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDriveUsageCard(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final driveUsed = clipProvider.googleDriveUsedBytes;
    final parrokitUsed = clipProvider.cloudStorageUsedBytes;
    final cloudQuota = clipProvider.cloudStorageQuotaBytes;
    final hasQuota = cloudQuota != null && cloudQuota > 0;
    final isLinked = clipProvider.hasGoogleDriveLinked;
    final isBusy = clipProvider.isGoogleDriveLinking;
    final otherUsed = math.max(driveUsed - parrokitUsed, 0);
    final remaining = hasQuota ? math.max(cloudQuota - driveUsed, 0) : 0;

    final segments = hasQuota
        ? <_StorageSegment>[
            _StorageSegment(
              value: otherUsed,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            _StorageSegment(
              value: parrokitUsed,
              color: Theme.of(context).colorScheme.primary,
            ),
            _StorageSegment(
              value: remaining,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ]
        : <_StorageSegment>[
            _StorageSegment(
              value: otherUsed,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            _StorageSegment(
              value: parrokitUsed,
              color: Theme.of(context).colorScheme.primary,
            ),
          ];

    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
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
                  isLinked ? 'Google Drive 연동됨' : 'Google Drive',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                ),
              ),
              TextButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        final provider = context.read<ClipProvider>();
                        if (provider.hasGoogleDriveLinked) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Google Drive 연동 해제'),
                              content: const Text(
                                '연동을 해제하면 Google Drive에 있던 파일들을 모두 기기로 옮긴 뒤, 계정을 분리합니다.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('취소'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('연동 해제'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;

                          final success =
                              await provider.disconnectGoogleDrive();
                          if (!context.mounted) return;
                          showToast(
                            success
                                ? 'Google Drive 연동을 해제했어요.'
                                : 'Google Drive 연동 해제에 실패했어요.',
                          );
                        } else {
                          final success = await provider.connectGoogleDrive();
                          if (!context.mounted) return;
                          showToast(
                            success
                                ? 'Google Drive 연동을 완료했어요.'
                                : 'Google Drive 연동에 실패했어요.',
                          );
                        }
                      },
                child: Text(isLinked ? '연동 해제' : '구글 드라이브 연동하기'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSegmentedBar(context, segments: segments),
          const SizedBox(height: 8),
          Text(
            hasQuota
                ? 'Drive 전체 사용량 안에서 Parrokit가 차지하는 실제 크기를 따로 분리해 보여줍니다.'
                : 'Drive 전체 사용량을 모두 가져오지 못해서 Parrokit 사용량 중심으로 보여줍니다.',
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
                label: 'Parrokit ${_formatBytes(parrokitUsed)}',
                color: cs.primary,
              ),
              _buildLegendChip(
                context,
                label: '기타 파일 ${_formatBytes(otherUsed)}',
                color: cs.surfaceContainerHigh,
              ),
              if (hasQuota)
                _buildLegendChip(
                  context,
                  label: '남은 공간 ${_formatBytes(remaining)}',
                  color: cs.surfaceContainerHighest,
                ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(999),
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
    final localUsed = clipProvider.localStorageUsedBytes;
    final serverUsed = clipProvider.serverStorageUsedBytes;
    final serverTotal = ClipProvider.serverStorageQuotaBytes;
    final serverProgress =
        serverTotal == 0 ? 0.0 : (serverUsed / serverTotal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('원격 저장소'),
        const SizedBox(height: 10),
        _buildToggle(context),
        if (_isExpanded) ...[
          const SizedBox(height: 10),
          CardContainer(
            child: Column(
              children: [
                _buildUsageCard(
                  context,
                  icon: Icons.phone_android_rounded,
                  title: '로컬',
                  subtitle: '이 기기에 남아 있어 오프라인에서도 바로 열 수 있는 파일입니다.',
                  usageText: _formatBytes(localUsed),
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildUsageCard(
                  context,
                  icon: Icons.cloud_queue_rounded,
                  title: '서버',
                  subtitle: '앱 서버에 저장된 파일과 메타데이터를 보여줍니다.',
                  usageText:
                      '${_formatBytes(serverUsed)} / ${_formatBytes(serverTotal)}',
                  color: Theme.of(context).colorScheme.secondary,
                  progress: serverProgress,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDriveUsageCard(context),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StorageSegment {
  const _StorageSegment({
    required this.value,
    required this.color,
  });

  final int value;
  final Color color;
}
