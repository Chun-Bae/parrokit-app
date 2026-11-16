// 긴 문장(200자)이 말풍선으로 무대를 덮지 않는다(5차 324).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/stage_preview_screen.dart';

void main() {
  const size = Size(390, 420);

  test('짧은 문장은 그대로, 긴 문장은 몇 줄에서 멈춘다', () {
    final short = stageBubbleRect(size, 'Can I get a latte?');
    final long = stageBubbleRect(size, 'A' * 200);
    final longer = stageBubbleRect(size, 'A' * 600);

    expect(long.height, greaterThan(short.height));
    // 200자든 600자든 같은 높이에서 멈춘다(넘치면 '…').
    expect(longer.height, long.height);
    // 무대(420) 절반을 넘지 않는다.
    expect(long.height, lessThan(size.height / 2));
  });

  test('말풍선은 화면 안에 들어온다', () {
    final rect = stageBubbleRect(size, '한국어로 아주 긴 문장을 넣어도 ' * 10);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(size.width));
  });
}
