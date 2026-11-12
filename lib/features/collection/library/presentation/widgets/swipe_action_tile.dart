import 'package:flutter/material.dart';

class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    super.key,
    required this.child,
    required this.actions,
    this.actionWidth = 160,
    this.onOpenChanged,
    this.minHeight = 64,
  });

  final Widget child;
  final List<Widget> actions;
  final double actionWidth;
  final double minHeight;
  final ValueChanged<bool>? onOpenChanged;

  @override
  SwipeActionTileState createState() => SwipeActionTileState();
}

class SwipeActionTileState extends State<SwipeActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180));
  late final Animation<double> _offset =
      Tween<double>(begin: 0, end: -widget.actionWidth).animate(_ctrl);

  bool _open = false;

  /// 동작 칸이 열려 있는지. 열린 줄을 누르면 닫기만 하려고 밖에서 본다.
  bool get isOpen => _open;

  void _snap(bool open) {
    setState(() => _open = open);
    if (open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    widget.onOpenChanged?.call(open);
  }

  void close() => _snap(false);

  void open() => _snap(true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      // 전체 폭 차지
      width: double.infinity,
      child: ClipRect(
        // 바깥으로 밀린 영역 잘라내기
        child: Stack(
          children: [
            // 뒤: 액션 바
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: widget.actionWidth,
                    height: double.infinity,
                    child: Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceEvenly, // ❌ 제거
                      children: widget.actions, // ← Expanded 2개가 가득 채움
                    ),
                  ),
                ],
              ),
            ),

            // 앞: 드래그로 움직이는 본문 (배경색 반드시 칠하기!)
            AnimatedBuilder(
              animation: _offset,
              builder: (_, __) => Transform.translate(
                offset: Offset(_offset.value, 0),
                // ⬇️ 이제 히트영역(탭/드래그)도 같이 이동함
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (d) {
                    final next = (_offset.value + d.delta.dx)
                        .clamp(-widget.actionWidth, 0.0);
                    _ctrl.value = (next / -widget.actionWidth).clamp(0.0, 1.0);
                  },
                  onHorizontalDragEnd: (d) {
                    final vx = d.primaryVelocity ?? 0;
                    if (vx < -300) return _snap(true);
                    if (vx > 300) return _snap(false);
                    _snap(_ctrl.value >= 0.5);
                  },
                  onTap: () {
                    if (_open) _snap(false);
                  },
                  child: Container(
                    color: cs.surface, // 배경 깔아 비침 방지
                    constraints: BoxConstraints(minHeight: widget.minHeight),
                    child: Material(
                      color: Colors.transparent,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
