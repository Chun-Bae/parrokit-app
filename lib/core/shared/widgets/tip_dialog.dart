// ============================================================================
// lib/features/_content/clip_editor/presentation/widgets/editor_tip_dialog.dart
// ============================================================================
//
// [역할]
// 클립 에디터 진입 시 표시되는 안내 다이얼로그.
// SharedPreferences로 오늘 하루 보지 않기를 관리합니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

const _prefKey = 'editor_tip_dismissed_date';

/// 오늘 이미 다이얼로그를 닫았는지 확인합니다.
Future<bool> shouldShowTip() async {
  final prefs = await SharedPreferences.getInstance();
  final dismissed = prefs.getString(_prefKey);
  final today = _todayString();
  return dismissed != today;
}

/// 오늘 하루 보지 않기 상태를 저장합니다.
Future<void> dismissTipForToday() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKey, _todayString());
}

String _todayString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// 에디터 진입 안내 다이얼로그를 표시합니다.
///
/// [force]: true이면 오늘 하루 보지 않기 여부와 관계없이 무조건 표시합니다.
/// 도움말 버튼 등에서 명시적으로 호출할 때 사용하세요.
Future<void> showTipDialog(BuildContext context, {bool force = false}) async {
  if (!force && !await shouldShowTip()) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _TipDialog(),
  );
}

class _TipDialog extends StatelessWidget {
  const _TipDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: cs.primary, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('이용 안내', style: tt.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 안내 항목 1
            _TipItem(
              icon: Icons.music_note_rounded,
              color: cs.tertiary,
              title: '노래 번역 품질',
              body:
                  '배경음이 강한 노래는 자막 생성이 잘 안될 수 있어요. 보컬이 명확한 곡일수록 더 좋은 결과를 얻을 수 있어요.',
            ),
            const SizedBox(height: AppSpacing.md),

            // 안내 항목 2
            _TipItem(
              icon: Icons.save_alt_rounded,
              color: cs.error,
              title: '동영상 백업 필수',
              body:
                  '편집한 동영상은 이 기기에만 저장돼요. 앱 삭제 또는 기기 초기화 시 영구적으로 삭제될 수 있으니 반드시 백업해 두세요.',
            ),
            const SizedBox(height: AppSpacing.md),

            // 안내 항목 3
            _TipItem(
              icon: Icons.science_outlined,
              color: cs.onPrimaryFixed,
              title: '베타 테스트 중',
              body:
                  '현재 베타 테스트 기간으로, 결제 기능이 임시로 빠진 상태예요. 정식 출시 시 결제 기능이 추가될 예정이에요.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // 버튼 영역
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    await dismissTipForToday();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('오늘 하루 보지 않기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(body,
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
