import 'package:flutter/material.dart';

/// [역할]
/// BookmarkTabs 내의 개별 탭 버튼.
class BookmarkTab extends StatelessWidget {
  const BookmarkTab({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// 유료화 준비 등으로 아직 쓸 수 없는 탭인지 여부. true면 옅게 표시하고
  /// 라벨 옆에 자물쇠 아이콘을 붙인다. 탭 자체는 여전히 눌리며, 눌렀을 때
  /// 어떤 안내를 보여줄지는 [onTap]을 넘기는 쪽에서 결정한다.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = locked
        ? cs.onSurface.withValues(alpha: 0.4)
        : (active ? cs.primary : cs.onSurface);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
            if (locked) ...[
              const SizedBox(width: 4),
              Icon(Icons.lock_rounded, size: 14, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}
