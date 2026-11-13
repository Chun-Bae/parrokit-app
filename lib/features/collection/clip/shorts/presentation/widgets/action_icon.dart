// ============================================================================
// lib/features/_content/shorts/presentation/widgets/action_icon.dart
// ============================================================================
//
// [역할]
// 쇼츠 화면 우측 액션 레일(ActionRail)에 사용되는 원형 아이콘 버튼입니다.
//
// [기능]
// - [icon]: 표시할 아이콘 (IconData)
// - [label]: 아이콘 아래에 표시될 텍스트 라벨
// - [active]: 활성화 상태 여부 (색상 변경)
// - [onTap]: 탭 이벤트 콜백
//
// [레이어]
// Presentation Layer > Widgets
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';

/// [역할]
/// 쇼츠 우측 패널의 개별 액션 버튼 위젯.
///
/// 원형 배경의 아이콘과 하단 라벨로 구성됩니다.
/// [active] 상태에 따라 아이콘과 라벨의 색상이 변경됩니다.
class ActionIcon extends StatelessWidget {
  const ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                icon,
                size: 26,
                color: active ? scheme.primary : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 쇼츠는 늘 영상 위라 테마 글자색(회색·주색)이 화면에 따라 묻혔다(5차).
          // 영상 위 글자처럼 흰색에 그림자를 준다. 켜짐 여부는 아이콘 색으로 본다.
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 4),
                Shadow(color: Colors.black54, blurRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [역할]
/// 자동 넘김(Auto Next) 기능을 토글하는 버튼 위젯.
///
/// 상태([_enabled])를 내부적으로 관리하며, 변경 시 [onChanged] 콜백을 호출합니다.
class AutoNextButton extends StatefulWidget {
  final bool initial;
  final ValueChanged<bool> onChanged;
  const AutoNextButton({
    super.key,
    this.initial = false,
    required this.onChanged,
  });

  @override
  State<AutoNextButton> createState() => _AutoNextButtonState();
}

class _AutoNextButtonState extends State<AutoNextButton> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "자동 넘겨가기",
      icon: Icon(_enabled ? Icons.playlist_play : Icons.playlist_remove),
      onPressed: () {
        setState(() => _enabled = !_enabled);
        widget.onChanged(_enabled);
      },
    );
  }
}
