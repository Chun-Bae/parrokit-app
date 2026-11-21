// 학습 캘린더 칸 색이 서로 구분되는지(5차 538).
//
// 1단계가 0단계와 너무 가까웠다(F0F5FA vs DDEAF8, RGB 차이 19·11·2).
// 흰 카드 위에서는 같은 색이라, 하루 목표 5번 중 1번을 한 날이 '안 한 날'과
// 구분되지 않았다. 기기에서 오늘 연습했는데 칸이 비어 보였다.
//
// 눈금이 다시 좁아지지 않게 단계 사이 거리를 지킨다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

/// 두 색이 얼마나 다른지. 각 채널 차이를 더해 본다.
int _distance(Color a, Color b) {
  int ch(double x, double y) => ((x - y).abs() * 255).round();
  return ch(a.r, b.r) + ch(a.g, b.g) + ch(a.b, b.b);
}

void main() {
  for (final (name, tokens) in [
    ('밝은 쪽', HomeTokens.light),
    ('어두운 쪽', HomeTokens.dark),
  ]) {
    group(name, () {
      test('단계가 다섯이다', () {
        expect(tokens.garden.length, 5);
      });

      test('이웃한 단계끼리 눈에 띄게 다르다', () {
        for (var i = 0; i < tokens.garden.length - 1; i++) {
          final gap = _distance(tokens.garden[i], tokens.garden[i + 1]);
          expect(gap, greaterThanOrEqualTo(60),
              reason: '$i단계와 ${i + 1}단계가 너무 가깝다(차이 $gap). '
                  '연습한 날이 안 한 날처럼 보인다.');
        }
      });

      test('연습한 날은 안 한 날과 확실히 다르다', () {
        // 1단계(목표의 3분의 1 미만)도 0단계와 분명히 갈려야 한다.
        final gap = _distance(tokens.garden[0], tokens.garden[1]);
        expect(gap, greaterThanOrEqualTo(60), reason: '차이 $gap');
      });

      test('진해지는 방향이 뒤집히지 않는다', () {
        // 0에서 4로 갈수록 바탕에서 멀어져야 한다.
        var previous = 0;
        for (var i = 1; i < tokens.garden.length; i++) {
          final far = _distance(tokens.garden[0], tokens.garden[i]);
          expect(far, greaterThan(previous), reason: '$i단계');
          previous = far;
        }
      });
    });
  }
}
