// 구독 화면이 안 뜨면 까닭을 알린다(5차 355).
//
// 출시 빌드는 RevenueCat Paywall을 띄우는데, 스토어 상품이나 대시보드 화면이
// 아직 없으면 조용히 notPresented가 돌아온다. 그러면 '구독'을 눌러도 아무 일도
// 일어나지 않는다. 이미 구독 중일 때도 같은 값이 와서 둘을 나눠 말해야 한다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

void main() {
  test('안내 글 셋은 서로 다른 것을 말한다', () {
    expect(subscriptionNotReadyToast, contains('아직'));
    expect(subscriptionAlreadyToast, contains('이미 구독'));
    expect(subscriptionOpenFailedToast, contains('열지 못했어요'));
    expect(
        {
          subscriptionNotReadyToast,
          subscriptionAlreadyToast,
          subscriptionOpenFailedToast,
        }.length,
        3);
  });

  test('진짜 Paywall은 안 떴을 때만, 구독 여부에 따라 알린다', () {
    final code = File(
            'lib/features/settings/subscription/presentation/paywall_presenter.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('if (result != PaywallResult.notPresented) return;'));
    // 459에서 갈래를 나눴다. 이미 구독 중이면 Paywall을 부르지 않고 바로
    // 알리고, 그 밖에 뜨지 않은 경우만 '아직 상품이 없다'고 말한다.
    expect(code, contains('if (premium) { showToast(subscriptionAlreadyToast); return; }'));
    expect(code, contains('showToast(subscriptionNotReadyToast);'));
    // 실패도 조용히 넘기지 않는다.
    expect(code, contains('showToast(subscriptionOpenFailedToast);'));
  });
}
