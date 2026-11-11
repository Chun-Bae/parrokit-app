import 'package:flutter/material.dart';

class CommunityHeaderDelegate extends SliverPersistentHeaderDelegate {
  CommunityHeaderDelegate({
    required this.titleWidget,
    required this.zone1Widget,
    required this.zone2Widget,
    this.zone2Height = 60.0,
  });

  final double titleHeight = 56.0;
  final double zone1Height = 48.0;

  /// 하위 필터 줄 높이. 탭마다 필터 모양이 달라서 바깥에서 정해 준다.
  /// 가로 스크롤 칩 줄은 60, 세그먼트 컨트롤은 그보다 높다.
  final double zone2Height;

  final Widget titleWidget;
  final Widget zone1Widget;
  final Widget zone2Widget;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent => titleHeight + zone1Height + zone2Height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final surface = Theme.of(context).colorScheme.surface;
    final titleTop = -shrinkOffset;

    double zone1Top;
    if (shrinkOffset <= titleHeight) {
      zone1Top = titleHeight - shrinkOffset;
    } else if (shrinkOffset <= titleHeight + zone2Height) {
      zone1Top = 0;
    } else {
      zone1Top = -(shrinkOffset - (titleHeight + zone2Height));
    }

    final zone2Top = (titleHeight + zone1Height) - shrinkOffset;

    return Container(
      color: surface,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: zone2Top,
            left: 0,
            right: 0,
            height: zone2Height,
            child: Container(color: surface, child: zone2Widget),
          ),
          Positioned(
            top: titleTop,
            left: 0,
            right: 0,
            height: titleHeight,
            child: Container(color: surface, child: titleWidget),
          ),
          Positioned(
            top: zone1Top,
            left: 0,
            right: 0,
            height: zone1Height,
            child: Container(color: surface, child: zone1Widget),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CommunityHeaderDelegate oldDelegate) => true;
}
