import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 저장 용량 막대의 한 칸.
class StorageSegment {
  const StorageSegment({required this.value, required this.color});

  /// 바이트 수. 0이면 그리지 않는다.
  final int value;
  final Color color;
}

/// 저장 용량 막대의 높이.
const double storageSegmentBarHeight = 10;

/// 막대를 나누는 단위. 비율을 정수 flex로 바꿀 때 쓴다.
const int storageSegmentResolution = 1000;

/// 값이 있는 칸이 적어도 차지하는 몫(2.5%). 막대가 340pt쯤이면 8pt 남짓이라
/// 눈에 보인다.
const int storageSegmentMinShare = 25;

/// 칸마다 쓸 flex 값. 값이 0인 칸은 0.
///
/// 비율 그대로 나누면 작은 칸이 한 픽셀도 안 돼 아예 안 보인다. Drive 전체
/// 123GB 안의 Parrokit 91KB가 그랬다. 범례에는 'Parrokit 91 KB'가 파란색으로
/// 있는데 막대에는 파란 칸이 없어서, "Parrokit가 차지하는 크기를 따로 보여
/// 준다"는 설명이 무색했다(5차). 값이 0보다 큰 칸은 적어도
/// [storageSegmentMinShare]만큼 주고, 모자란 몫은 넉넉한 칸에서 뗀다.
@visibleForTesting
List<int> storageSegmentFlex(
  List<int> values, {
  int resolution = storageSegmentResolution,
  int minShare = storageSegmentMinShare,
}) {
  final flex = List<int>.filled(values.length, 0);
  final positives = [
    for (var i = 0; i < values.length; i++)
      if (values[i] > 0) i,
  ];
  if (positives.isEmpty) return flex;

  // 칸이 너무 많아 최소 몫도 못 주면 똑같이 나눈다.
  if (positives.length * minShare >= resolution) {
    final each = (resolution / positives.length).floor();
    for (final i in positives) {
      flex[i] = each < 1 ? 1 : each;
    }
    return flex;
  }

  final sum = positives.fold<int>(0, (acc, i) => acc + values[i]);
  for (final i in positives) {
    flex[i] = (resolution * values[i] / sum).round();
  }

  var deficit = 0;
  for (final i in positives) {
    if (flex[i] < minShare) {
      deficit += minShare - flex[i];
      flex[i] = minShare;
    }
  }
  if (deficit <= 0) return flex;

  final donors = [
    for (final i in positives)
      if (flex[i] > minShare) i,
  ];
  final spare = donors.fold<int>(0, (acc, i) => acc + (flex[i] - minShare));
  if (spare <= 0) return flex;
  for (final i in donors) {
    flex[i] -= (deficit * (flex[i] - minShare) / spare).round();
    if (flex[i] < minShare) flex[i] = minShare;
  }
  return flex;
}

/// 로컬·서버·Drive 사용량을 한 줄 막대로 보여 준다.
///
/// 전에는 더보기의 저장 용량과 보관함 폴더 화면이 같은 막대를 따로 들고
/// 있었다(5차에 하나로 모았다).
class StorageSegmentBar extends StatelessWidget {
  const StorageSegmentBar({super.key, required this.segments});

  final List<StorageSegment> segments;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = segments.where((s) => s.value > 0).toList();
    final flex = storageSegmentFlex([for (final s in shown) s.value]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: storageSegmentBarHeight,
        // 자식 없는 ColoredBox는 느슨한 세로 제약에서 높이가 0이 돼 아무것도
        // 안 보인다. 칸을 채우는 Container를 쓰고, Row도 세로로 늘린다(5차).
        child: shown.isEmpty
            ? Container(color: cs.surfaceContainerHigh)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Expanded(
                      flex: flex[i] < 1 ? 1 : flex[i],
                      child: Container(color: shown[i].color),
                    ),
                ],
              ),
      ),
    );
  }
}
