// 머리와 바닥은 제자리에 두고 가운데만 구르는 시트의 가운데(5차 566).
//
// 머리 바로 아래에서 내용이 칼로 자른 듯 끊겼다. 기기에서 보니 '웹에서
// 찾기' 단추의 둥근 아랫단이 반쯤 잘린 채 부제 줄 옆에 남아, 무언가
// 깨진 것처럼 보였다. 구르기 시작한 뒤에만 위 가장자리를 짧게 흐린다 -
// 맨 위에서는 첫 줄이 또렷해야 한다.

import 'package:flutter/material.dart';

class SheetScrollBody extends StatefulWidget {
  const SheetScrollBody({
    super.key,
    required this.child,
    this.fade = 16,
    this.controller,
    this.padding,
  });

  final Widget child;

  /// 구르는 내용의 안쪽 여백. [SingleChildScrollView.padding]과 같다.
  final EdgeInsetsGeometry? padding;

  /// 흐려지는 띠의 높이(논리 픽셀).
  final double fade;

  /// 밖에서 스크롤을 잡고 싶을 때. 없으면 제 것을 만든다.
  final ScrollController? controller;

  @override
  State<SheetScrollBody> createState() => SheetScrollBodyState();
}

@visibleForTesting
class SheetScrollBodyState extends State<SheetScrollBody> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();

  double _amount = 0;

  /// 0이면 맨 위(흐리지 않는다), 1이면 띠를 다 쓴다.
  @visibleForTesting
  double get fadeAmount => _amount;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final next = widget.fade <= 0
        ? 0.0
        : (_controller.offset / widget.fade).clamp(0.0, 1.0);
    // 한 프레임에 여러 번 불려도 눈에 보일 만큼 바뀔 때만 다시 그린다.
    if ((next - _amount).abs() < 0.02) return;
    setState(() => _amount = next);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    // 밖에서 받은 것은 밖이 버린다.
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      controller: _controller,
      padding: widget.padding,
      child: widget.child,
    );
    // 흐림이 없을 때도 ShaderMask를 벗기지 않는다. 트리 깊이가 바뀌면
    // Scrollable이 다시 만들어져 구르던 자리가 맨 위로 튄다(테스트에서
    // 잡았다). 맨 위에서는 그라데이션이 전부 불투명이라 보이는 것은
    // 같다.
    return ShaderMask(
      shaderCallback: (rect) {
        final span = rect.height <= 0 ? 1.0 : widget.fade / rect.height;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 1 - _amount),
            Colors.black,
          ],
          stops: [0, span.clamp(0.0, 1.0)],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: scroll,
    );
  }
}
