// 구독 혜택에 적는 숫자는 한 곳에서만 온다(5차 315).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

void main() {
  test('매달 패롯은 서버(subscriptionGrant.ts)와 같은 값이다', () {
    final ts = File('functions/src/subscriptionGrant.ts').readAsStringSync();
    // export const DEFAULT_GRANTS: TierLimits = {free: 0, light: 100, pro: 400};
    final line = RegExp(r'DEFAULT_GRANTS[^=]*=\s*\{([^}]*)\}').firstMatch(ts);
    expect(line, isNotNull, reason: '서버 쪽 기본값을 찾지 못했다');
    final body = line!.group(1)!;

    int serverValue(String key) =>
        int.parse(RegExp('$key:\\s*(\\d+)').firstMatch(body)!.group(1)!);

    expect(monthlyParrotsFor(SubscriptionTier.free), serverValue('free'));
    expect(monthlyParrotsFor(SubscriptionTier.light), serverValue('light'));
    expect(monthlyParrotsFor(SubscriptionTier.pro), serverValue('pro'));
  });

  test('혜택 줄은 박아 둔 숫자가 아니라 값에서 만든다', () {
    final light = subscriptionTiers
        .firstWhere((copy) => copy.tier == SubscriptionTier.light);
    final pro =
        subscriptionTiers.firstWhere((copy) => copy.tier == SubscriptionTier.pro);

    expect(light.benefits, contains('매달 패롯 ${monthlyParrotsFor(SubscriptionTier.light)}개'));
    expect(pro.benefits, contains('매달 패롯 ${monthlyParrotsFor(SubscriptionTier.pro)}개'));
    expect(light.benefits,
        contains('서버 백업 ${serverStorageQuotaLabel(SubscriptionTier.light)}'));
    expect(pro.benefits,
        contains('서버 백업 ${serverStorageQuotaLabel(SubscriptionTier.pro)}'));

    // 화면 글 파일에 숫자를 다시 적어 두지 않는다(주석은 뺀다).
    final code =
        File('lib/features/settings/subscription/presentation/subscription_texts.dart')
            .readAsStringSync()
            .split('\n')
            .where((line) => !line.trimLeft().startsWith('//') &&
                !line.trimLeft().startsWith('///'))
            .join('\n');
    expect(code.contains('매달 패롯 100개'), isFalse);
    expect(code.contains('서버 백업 5GB'), isFalse);
  });

  test('뜻 채우기 한도는 숫자를 적지 않는다', () {
    // 서버 설정(sentenceAssist의 tierLimits)에서 바뀌는 값이라, 적어 두면
    // 화면이 거짓말을 하게 된다. 다른 안내(assistQuotaUpsellText)도 같은 규칙.
    for (final copy in subscriptionTiers) {
      final line =
          copy.benefits.firstWhere((benefit) => benefit.contains('뜻 채우기'));
      expect(RegExp(r'\d').hasMatch(line), isFalse, reason: line);
    }
    expect(RegExp(r'\d').hasMatch(assistQuotaUpsellText), isFalse);
  });

  test('서버 저장 한도 표기는 바이트 값과 맞는다', () {
    expect(serverStorageQuotaLabel(SubscriptionTier.light), '5GB');
    expect(serverStorageQuotaLabel(SubscriptionTier.pro), '30GB');
  });
}
