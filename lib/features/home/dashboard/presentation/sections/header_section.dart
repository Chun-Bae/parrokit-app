// ============================================================================
// lib/features/dashboard/presentation/sections/header_section.dart
// ============================================================================
//
// [역할]
// 대시보드 상단 헤더 섹션.
// 로고, 클립 수 카운터 애니메이션 표시.
//
// [레이어]
// Presentation Layer > Sections
// DashboardScreen에서만 사용하는 화면 전용 섹션.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import '../widgets/gradient_icon.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 대시보드 상단 헤더 섹션.
///
/// - 로고 뱃지
/// - 클립 수 카운터 (숨쉬기 애니메이션 + 숫자 트윈)
class HeaderSection extends StatefulWidget {
  const HeaderSection({super.key});

  @override
  State<HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<HeaderSection>
    with SingleTickerProviderStateMixin {
  // ─────────────────────────────────────────────────────────────────
  // 애니메이션 컨트롤러
  // ─────────────────────────────────────────────────────────────────

  /// 로딩 중 "숨쉬기" 애니메이션 컨트롤러
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  /// 트윈 애니메이션용 값 추적
  int _prevFinal = 0;
  int _target = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // 1.0 ↔ 1.04 정도의 미세한 스케일로 '숨쉬기' 느낌
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    // 0.72 ↔ 1.0 정도의 미세한 투명도 변화
    _fade = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = context.tokens.textPrimary;

    final dup = context.watch<ClipActivityProvider>();
    final isLoading = dup.isCounting;
    _target = dup.clipCount;

    // 로딩 상태에 따라 숨쉬기 애니 on/off
    if (isLoading) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) _pulse.stop();
    }

    // 그라데이션 숫자 스타일
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.gradientStart, AppColors.gradientEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, 200, 40));

    final numberStyle = context.texts.headlineSmall
        .copyWith(foreground: gradientPaint, height: 1.0);

    // 트윈 시작/끝점
    final tweenBegin = _prevFinal;
    final tweenEnd = _target;
    if (!isLoading) _prevFinal = _target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          // 로고 뱃지
          const GradientIcon(),
          const SizedBox(width: 12),

          // 클립 수 + 문구
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // 숫자 애니메이션
                    isLoading
                        ? ScaleTransition(
                            scale: _scale,
                            child: FadeTransition(
                              opacity: _fade,
                              child: Text('$_prevFinal', style: numberStyle),
                            ),
                          )
                        : TweenAnimationBuilder<double>(
                            key: ValueKey(tweenEnd),
                            tween: Tween<double>(
                              begin: tweenBegin.toDouble(),
                              end: tweenEnd.toDouble(),
                            ),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInSine,
                            builder: (_, v, __) => Text(
                              '${v.round()}',
                              style: numberStyle,
                            ),
                          ),
                    const SizedBox(width: 4),
                    Text(
                      '개의 클립을 모았어요 🎬',
                      style: context.texts.titleLarge.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('오늘도 한 장면씩 👋', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
