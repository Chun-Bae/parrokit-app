// 서버만 쓰는 칸은 firestore.rules가 앱의 쓰기를 막아야 한다(5차 537).
//
// users/{uid} 문서는 본인이 통째로 쓸 수 있다. 그래서 잔액이나 권한이 되는
// 칸은 규칙에서 따로 막는다. 그런데 새 칸을 만들 때 그 목록에 넣는 걸
// 잊기 쉽다 - 실제로 exampleCredits·assistCredits가 빠져 있었고, 앱이
// 패롯을 내지 않고도 AI 한도를 무한히 올릴 수 있었다.
//
// 서버 코드가 users 문서에 쓰는 '돈이 되는 칸'을 모아, 규칙 목록과 맞는지
// 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 서버(Admin SDK)만 정해야 하는 칸. 새로 만들면 여기와 규칙에 함께 넣는다.
const serverOnlyFields = [
  'subscription',
  'subParrots',
  'storage',
  'exampleCredits',
  'assistCredits',
];

void main() {
  test('규칙이 서버 전용 칸을 모두 막는다', () {
    final rules = File('firestore.rules').readAsStringSync();
    // users/{userId}의 update 규칙 안에 있는 hasAny 목록을 읽는다.
    final block = RegExp(r'hasAny\(\s*\[([^\]]*)\]').firstMatch(rules);
    expect(block, isNotNull, reason: '서버 전용 칸 목록을 찾지 못했다');
    final listed = RegExp("'([a-zA-Z]+)'")
        .allMatches(block!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();

    for (final field in serverOnlyFields) {
      expect(listed, contains(field),
          reason: '$field를 앱이 직접 쓸 수 있으면 그대로 돈이 된다');
    }
  });

  test('서버가 쓰는 잔액 칸이 목록에서 빠지지 않았다', () {
    // wallet.ts가 users 문서에 적는 칸들. crackers·parrots는 규칙이 따로
    // 다루므로(올리는 쪽만 허용) 여기서는 뺀다.
    final wallet = File('functions/src/wallet.ts').readAsStringSync();
    for (final field in ['subParrots', 'exampleCredits', 'assistCredits']) {
      expect(wallet, contains(field),
          reason: '$field가 서버에서 사라졌다면 규칙 목록도 함께 정리한다');
      expect(serverOnlyFields, contains(field));
    }
  });
}
