// 구매 복원 결과를 가려 말한다(5차 356).
//
// 전에는 스토어까지 못 갔을 때도 '복원할 구독을 찾지 못했어요'라고 해서,
// 인터넷이 끊긴 것을 구독이 없는 것으로 읽었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

void main() {
  test('세 가지 결과가 서로 다른 말을 쓴다', () {
    expect(subscriptionRestoreDoneToast, contains('복원했어요'));
    expect(subscriptionRestoreNoneToast, contains('찾지 못했어요'));
    expect(subscriptionRestoreFailedToast, contains('인터넷'));
    expect(
        {
          subscriptionRestoreDoneToast,
          subscriptionRestoreNoneToast,
          subscriptionRestoreFailedToast,
        }.length,
        3);
  });

  test('복원은 스토어에 닿았는지 먼저 보고 말한다', () {
    final code = File(
            'lib/features/settings/subscription/presentation/subscription_actions.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(
        code, contains('final reached = await provider.restorePurchases();'));
    expect(
        code,
        contains(
            'if (!reached) { showToast(subscriptionRestoreFailedToast); return; }'));
  });

  test('저장소는 실패를 삼키지 않고 알려 준다', () {
    final code = File('lib/core/state/provider/iap_provider.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('Future<bool> restorePurchases() async'));
    expect(code, contains('return false;'));
  });
}
