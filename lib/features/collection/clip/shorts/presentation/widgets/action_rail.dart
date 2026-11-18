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

/// 레일이 화면 오른쪽에서 떨어진 거리.
const double shortsActionRailRight = 12;

/// 레일이 차지하는 가로 폭. 가장 넓은 글자('자동 넘김')가 들어갈 만큼이다.
const double shortsActionRailWidth = 72;

/// 자막을 화면 오른쪽에서 띄울 거리(5차 492).
///
/// 자막은 `left: 16, right: 16`으로 가로를 다 쓰고 있었고 레일은 그 위에
/// 떠 있어서, 긴 자막의 첫 줄이 '연습' 단추 글자를 가로질렀다. 짧은
/// 자막에서는 안 보이는 결함이었다. 레일 자리를 비워 둔다.
const double shortsSubtitleRightInset =
    shortsActionRailRight + shortsActionRailWidth + 8;

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
    // 폭을 정해 둔다. 자막이 비워 둘 자리와 같은 값이어야 한다(5차 492).
    return SizedBox(
      width: shortsActionRailWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ AutoNext toggle
          ActionIcon(
            icon: Icons.playlist_play,
            label: "자동 넘김",
            active: autoNextEnabled,
            toggle: true,
            onTap: () => onAutoNextChanged(!autoNextEnabled),
          ),

          const SizedBox(height: 16),
          // ✅ Subtitle toggle
          ActionIcon(
            icon:
                showSubtitle ? Icons.closed_caption : Icons.closed_caption_off,
            label: "자막",
            active: showSubtitle,
            toggle: true,
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
      ),
    );
  }
}
