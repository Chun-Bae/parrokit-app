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

/// 자동으로 한 번 보여줬는지. 전에는 "오늘 하루 보지 않기"를 누르기 전까지
/// 홈 탭에 들어올 때마다 떠서, 탭을 오갈 때마다 화면을 막았다.
const _seenKey = 'tip_dialog_auto_shown_v1';

/// 아직 자동으로 보여준 적이 없으면 true.
Future<bool> shouldShowTip() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_seenKey) != true;
}

Future<void> _markTipShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_seenKey, true);
}

/// 이용 안내 다이얼로그를 표시합니다.
///
/// 자동 호출은 설치 뒤 처음 한 번만 보여준다. [force]가 true면(더보기 >
/// 도움말) 언제든 보여준다.
Future<void> showTipDialog(BuildContext context, {bool force = false}) async {
  if (!force) {
    if (!await shouldShowTip()) return;
    await _markTipShown();
  }
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

            // 안내 항목 1. 예전 문구는 '노래 번역 품질'이었는데 앱에 노래·가사
            // 기능이 없다. 실제로 있는 것은 영상 자동 자막이고, 자막 화면의
            // 안내(edit_strings.segmentsNotice)와 같은 말로 맞춘다(5차).
            _TipItem(
              icon: Icons.closed_caption_outlined,
              color: cs.tertiary,
              title: '자동 자막 정확도',
              body:
                  '소음이나 음악이 많은 영상에선 자동 자막 정확도가 낮을 수 있어요. 말소리가 또렷한 영상일수록 더 좋은 결과를 얻을 수 있어요.',
            ),
            const SizedBox(height: AppSpacing.md),

            // 안내 항목 2. 예전 문구는 '이 기기에만 저장돼요'였는데 지금은 서버·
            // Google Drive에도 둘 수 있어 틀린 말이 됐다(5차). 사라질 수 있는 건
            // '로컬' 클립뿐이고, 옮기는 방법을 함께 알려 준다.
            _TipItem(
              icon: Icons.save_alt_rounded,
              color: cs.error,
              title: '로컬 클립은 백업해 두세요',
              body:
                  "'로컬'에 둔 클립은 이 기기에만 있어서 앱을 지우거나 기기를 초기화하면 사라져요. 오래 둘 클립은 보관함에서 클립을 왼쪽으로 밀어 '옮기기'로 서버나 Google Drive에 옮기거나, 더보기의 백업으로 내보내 두세요.",
            ),
            const SizedBox(height: AppSpacing.md),

            // 안내 항목 3
            _TipItem(
              icon: Icons.science_outlined,
              // onPrimaryFixed는 다크에서도 짙은 남색이라 아이콘이 거의 안 보였다(5차).
              color: cs.primary,
              title: '베타 테스트 중',
              body:
                  '현재 베타 테스트 기간으로, 결제 기능이 임시로 빠진 상태예요. 정식 출시 시 결제 기능이 추가될 예정이에요.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // 버튼 영역. 처음 한 번만 자동으로 뜨므로 "오늘 하루 보지 않기"는 뺐다.
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
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
