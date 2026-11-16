// ============================================================================
// lib/features/_content/shorts/presentation/sections/shorts_page_subtitle_section.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 내 자막(일본어/발음/번역) 표시 영역.
//
// [레이어]
// Presentation Layer > Section
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/video_subtitle_style.dart';

/// [역할]
/// 영상의 현재 재생 구간(Segment)에 맞춰 자막을 표시하는 위젯.
///
/// 설정([showSubtitle])에 따라 자막 표시 여부를 결정하며,
/// 원문(일본어), 발음, 번역을 각각 다른 스타일로 렌더링합니다.
class ShortsPageSubtitleSection extends StatelessWidget {
  const ShortsPageSubtitleSection({
    super.key,
    required this.segment,
    required this.showSubtitle,
  });

  final Segment segment;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    if (!showSubtitle) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 일본어 원문
        Text(
          segment.original,
          textAlign: TextAlign.center,
          style: _originalStyle,
        ),

        // 발음 (옵션)
        if (segment.pron.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              segment.pron,
              textAlign: TextAlign.center,
              style: _pronStyle,
            ),
          ),

        // 번역 (옵션)
        if (segment.trans.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              segment.trans,
              textAlign: TextAlign.center,
              style: _transStyle,
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Styles
  // ─────────────────────────────────────────────────────────────────

  // 그림자와 발음 색은 플레이어 자막과 같은 곳에서 가져온다(5차).
  // 따로 적어 두니 한쪽만 고쳐져 플레이어 발음 줄이 안 보이는 채로 남았다.
  static const _shadows = videoSubtitleShadows;

  // 정적 상수라 BuildContext가 없다. 크기는 같은 스케일에서 가져온다.
  static final _originalStyle = AppTextScale.titleLarge
      .copyWith(color: Colors.white, height: 1.25, shadows: _shadows);

  static final _pronStyle = AppTextScale.bodyMedium
      .copyWith(
          color: videoSubtitlePronColor, height: 1.25, shadows: _shadows);

  static final _transStyle = AppTextScale.bodyLarge
      .copyWith(color: Colors.white, height: 1.25, shadows: _shadows);
}
