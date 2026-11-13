// ============================================================================
// lib/features/_content/shorts/presentation/widgets/action_rail.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 우측에 배치되는 액션 버튼들의 모음(Rail).
//
// [기능]
// - 자동 넘김(Auto Next) 토글
// - 자막(Subtitle) 표시 토글
// - 외부 플레이어(Player) 열기
//
// [레이어]
// Presentation Layer > Widgets
//
// ============================================================================

import 'package:flutter/material.dart';
import 'action_icon.dart';

/// [역할]
/// 쇼츠 화면 우측 사이드바(액션 레일).
///
/// 여러 개의 [ActionIcon]을 세로로 배치하여 주요 기능을 제공합니다.
class ActionRail extends StatelessWidget {
  final bool autoNextEnabled;
  final void Function(bool enabled) onAutoNextChanged;
  final VoidCallback onOpenExternalPlayer;

  final bool showSubtitle;
  final void Function(bool enabled) onSubtitleChanged;

  const ActionRail({
    super.key,
    required this.autoNextEnabled,
    required this.onAutoNextChanged,
    required this.onOpenExternalPlayer,
    required this.showSubtitle,
    required this.onSubtitleChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 글자가 영어(Auto·CC·Player)라 다른 화면과 달랐다(5차). 한국어로 맞춘다.
    // '연습'은 이 클립을 구간 반복·한 줄씩 멈춤이 있는 플레이어로 연다.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ AutoNext toggle
        ActionIcon(
          icon: Icons.playlist_play,
          label: "자동 넘김",
          active: autoNextEnabled,
          onTap: () => onAutoNextChanged(!autoNextEnabled),
        ),

        const SizedBox(height: 16),
        // ✅ Subtitle toggle
        ActionIcon(
          icon: showSubtitle ? Icons.closed_caption : Icons.closed_caption_off,
          label: "자막",
          active: showSubtitle,
          onTap: () => onSubtitleChanged(!showSubtitle),
        ),
        const SizedBox(height: 16),

        // ✅ External player
        ActionIcon(
          icon: Icons.open_in_new,
          label: "연습",
          onTap: onOpenExternalPlayer,
        ),
      ],
    );
  }
}
