// 스크롤하면 접히는 머리줄을 n단으로 쌓는 모듈(5차 332, 사용자 요청).
//
// 커뮤니티 앱바가 하던 일(제목 줄은 올라가 사라지고, 탭 줄은 맨 위에 붙어
// 버티다가 마지막에 사라지고, 필터 줄은 같이 접힌다)을 화면마다 다시 짜지 않게
// 단(tier) 목록으로 받는다. 1단이든 3단이든 같은 규칙으로 움직인다.

import 'package:flutter/material.dart';

/// 머리줄 한 단.
class HeaderTier {
  const HeaderTier({
    required this.height,
    required this.child,
    this.sticky = false,
  });

  /// 이 단의 높이(픽셀). 단마다 다를 수 있다.
  final double height;

  final Widget child;

  /// 맨 위에 붙어 버틸지. 붙은 단은 아래 단들이 다 접힌 뒤에야 같이 올라간다.
  /// 탭 줄처럼 '어디에 있는지'를 계속 보여 줘야 하는 단에 쓴다.
  final bool sticky;
}

/// [tiers]를 위에서부터 쌓아 접히는 머리줄을 만든다.
///
/// `SliverPersistentHeader(floating: true, delegate: TieredHeaderDelegate(...))`
/// 꼴로 `NestedScrollView`의 headerSliverBuilder에 넣어 쓴다.
class TieredHeaderDelegate extends SliverPersistentHeaderDelegate {
  TieredHeaderDelegate({required this.tiers, this.background});

  final List<HeaderTier> tiers;

  /// 머리줄 바탕색. 비우면 테마의 surface.
  final Color? background;

  @override
  double get minExtent => 0;

  @override
  double get maxExtent =>
      tiers.fold<double>(0, (sum, tier) => sum + tier.height);

  /// [index]번 단의 위쪽 좌표. 접힌 양([shrinkOffset])에 따라 달라진다.
  @visibleForTesting
  double topOf(int index, double shrinkOffset) {
    final before = tiers.take(index).fold<double>(0, (s, t) => s + t.height);
    if (!tiers[index].sticky) return before - shrinkOffset;

    // 붙는 단: 자기 자리까지는 같이 올라오고, 맨 위에 닿으면 아래 단들이
    // 다 접힐 때까지 버틴다. 그 뒤에는 같이 올라간다.
    final after = tiers.skip(index + 1).fold<double>(0, (s, t) => s + t.height);
    if (shrinkOffset <= before) return before - shrinkOffset;
    if (shrinkOffset <= before + after) return 0;
    return (before + after) - shrinkOffset;
  }

  /// 그리는 차례. 붙는 단이 위로 오게 나중에 그린다.
  @visibleForTesting
  List<int> paintOrder() {
    final normal = <int>[];
    final sticky = <int>[];
    for (var i = 0; i < tiers.length; i++) {
      (tiers[i].sticky ? sticky : normal).add(i);
    }
    return [...normal.reversed, ...sticky];
  }

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final surface = background ?? Theme.of(context).colorScheme.surface;
    return Container(
      color: surface,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final index in paintOrder())
            Positioned(
              top: topOf(index, shrinkOffset),
              left: 0,
              right: 0,
              height: tiers[index].height,
              child: Container(color: surface, child: tiers[index].child),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant TieredHeaderDelegate old) =>
      old.tiers.length != tiers.length ||
      old.background != background ||
      List.generate(tiers.length, (i) => i).any((i) =>
          old.tiers[i].height != tiers[i].height ||
          old.tiers[i].sticky != tiers[i].sticky ||
          old.tiers[i].child != tiers[i].child);
}

/// 접히는 머리줄 + 본문. 화면에서 바로 쓰는 껍데기.
class TieredHeaderScroll extends StatelessWidget {
  const TieredHeaderScroll({
    super.key,
    required this.tiers,
    required this.body,
    this.controller,
    this.background,
  });

  final List<HeaderTier> tiers;
  final Widget body;
  final ScrollController? controller;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      controller: controller,
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverPersistentHeader(
          floating: true,
          delegate: TieredHeaderDelegate(tiers: tiers, background: background),
        ),
      ],
      body: body,
    );
  }
}
