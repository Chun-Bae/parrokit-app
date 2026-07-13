import 'package:flutter/material.dart';

/// 콜렉션 화면의 스크롤 접힘 헤더.
///
/// [CommunityHeaderDelegate]와 동일한 3구역 stagger 방식(zone2가 가장
/// 먼저 밀려나고, zone1이 top에 가장 오래 고정)을 따르되, 탭에 따라
/// zone1/zone2 높이가 달라져야 해서(예: 클립 탭에서만 zone2가 보임)
/// 두 높이를 생성자 파라미터로 받는다.
class CollectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  CollectionHeaderDelegate({
    required this.titleWidget,
    required this.zone1Widget,
    required this.zone2Widget,
    this.zone1Height = 48.0,
    this.zone2Height = 0.0,
  });

  final double titleHeight = 56.0;
  final double zone1Height;
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
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
  bool shouldRebuild(covariant CollectionHeaderDelegate oldDelegate) => true;
}
