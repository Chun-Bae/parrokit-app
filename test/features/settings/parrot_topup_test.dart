// 지갑 카드의 '충전' 버튼(5차 464).
//
// 카드 설명은 '패롯은 … 광고를 보거나 충전해서 받아요'라고 하면서
// 충전할 길은 주지 않았다. 광고 제거와 같은 결함이다(463).
// CoinStoreSection이라는 위젯이 남아 있었지만 어느 화면도 쓰지 않았다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/sections/store_paywall.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

const _wallet =
    'lib/features/settings/more/presentation/sections/wallet_section.dart';
const _shared =
    'lib/features/settings/more/presentation/sections/store_paywall.dart';

void main() {
  test('말한 대로 충전할 길을 준다', () {
    final code = _code(_wallet);
    expect(code, contains("'충전'"));
    expect(code, contains('parrot-topup'));
    expect(code, contains('showParrotStorePaywall(context)'));
  });

  test('충전 설명과 버튼이 한 카드 안에 같이 있다', () {
    final code = _code(_wallet);
    // 설명이 '충전해서 받아요'라고 말한다.
    expect(code, contains('충전해서 받아요'));
  });

  test('어느 가게를 띄울지 짚어 준다', () {
    expect(parrotStoreOfferingId, 'parrokit_coins');
    expect(adsRemovalOfferingId, 'parrokit_ads_removed');
    final shared = _code(_shared);
    expect(shared, contains('offerings.all[offeringId]'));
    // 없으면 엉뚱한 화면 대신 까닭을 말한다.
    expect(shared, contains('if (offering == null)'));
  });

  test('못 띄웠을 때 할 말이 가게마다 다르다', () {
    expect(parrotStoreNotReadyToast, contains('패롯'));
    expect(adsRemovalNotReadyToast, contains('광고 제거'));
  });

  test('같은 흐름을 두 벌로 적지 않는다', () {
    final ads = _code(
        'lib/features/settings/more/presentation/sections/ads_removal_section.dart');
    // 실제 호출은 공용 파일 한 곳에만 있다.
    expect(ads.contains('RevenueCatUI.presentPaywall'), isFalse);
    expect(_code(_wallet).contains('RevenueCatUI.presentPaywall'), isFalse);
  });
}
