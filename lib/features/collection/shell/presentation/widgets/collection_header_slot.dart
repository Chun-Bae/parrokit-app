// 탭 안쪽 화면이 보관함 머리줄에 자기 단을 올려 두는 자리(5차 336, 사용자 요청).
//
// 왜 필요한가: 커뮤니티 앱바는 덜 중요한 줄부터 접힌다(제목 → 필터 → 탭).
// 탭 줄은 맨 위에 붙어 마지막까지 버틴다. 보관함은 앱바 · 탭은 바깥
// NestedScrollView의 머리줄이고, 언어·주제 줄과 둘러보기 줄은 탭 안쪽
// 목록의 단이었다. 바깥이 먼저 접히니 순서가 앱바 → 탭 → 필터가 됐다.
//
// 안쪽 줄들을 바깥 머리줄로 올리면 순서를 커뮤니티처럼 맞출 수 있다. 다만
// 그 줄에 쓰는 값(고른 언어, 공유 문장 목록)은 탭 안쪽 화면이 들고 있다.
// 그래서 값을 옮기지 않고, 그리는 함수만 올려 둔다.
//
// 되돌아가며 다시 그리는 일을 막는 방법: 단 높이가 달라질 때만 바깥 화면을
// 다시 그리고(onHeightsChanged), 내용만 바뀌면 [revision]을 올려 그 단만
// 다시 그린다. 안쪽 화면은 build 뒤(post frame)에 올려 둔다.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';

class CollectionHeaderSlot {
  CollectionHeaderSlot({required this.onHeightsChanged});

  /// 단 수나 높이가 바뀌어 바깥 머리줄을 다시 재야 할 때 부른다.
  final VoidCallback onHeightsChanged;

  /// 내용만 바뀐 것. 이 값을 보고 그 단만 다시 그린다.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<double> _heights = const [];
  Widget Function(int index)? _builder;

  bool get isEmpty => _heights.isEmpty;

  /// 안쪽 화면이 자기 단을 올려 둔다. build 안에서 바로 부르지 않고
  /// addPostFrameCallback으로 부른다(그리는 중에 다시 그리라고 하면 터진다).
  void put({
    required List<double> heights,
    required Widget Function(int index) build,
  }) {
    _builder = build;
    final changed = !listEquals(_heights, heights);
    _heights = List<double>.unmodifiable(heights);
    revision.value++;
    if (changed) onHeightsChanged();
  }

  /// 안쪽 화면이 사라질 때. 올려 둔 단을 내린다.
  void clear() {
    _builder = null;
    if (_heights.isEmpty) return;
    _heights = const [];
    onHeightsChanged();
  }

  List<HeaderTier> tiers() => [
        for (var i = 0; i < _heights.length; i++)
          HeaderTier(
            height: _heights[i],
            child: ValueListenableBuilder<int>(
              valueListenable: revision,
              builder: (_, __, ___) =>
                  _builder?.call(i) ?? const SizedBox.shrink(),
            ),
          ),
      ];

  void dispose() => revision.dispose();
}
