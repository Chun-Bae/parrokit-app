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

    // 단계를 하나씩 적어 두면 새 단계가 빠진다. 실제로 플러스·맥스를
    // 더한 뒤에도 free·light·pro만 보고 있었다(5차 551).
    for (final tier in SubscriptionTier.values) {
      expect(monthlyParrotsFor(tier), serverValue(tier.name),
          reason: tier.name);
    }
  });

  test('혜택 줄은 박아 둔 숫자가 아니라 값에서 만든다', () {
    for (final copy in subscriptionTiers) {
      expect(copy.benefits, contains('매달 패롯 ${monthlyParrotsFor(copy.tier)}개'),
          reason: copy.tier.name);
      expect(copy.benefits,
          contains('서버 백업 ${serverStorageQuotaLabel(copy.tier)}'),
          reason: copy.tier.name);
    }

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

  // 전에는 '뜻 채우기 한도는 숫자를 적지 않는다'를 지켰다. 서버 설정으로
  // 바뀌면 화면이 거짓말을 한다는 까닭이었는데, 바로 옆 예문 한도는 이미
  // 숫자를 적고 있어서 규칙이 한쪽에만 걸려 있었다. 그래서 사용자는 한도가
  // 두 가지라는 것도, 뜻·발음이 얼마나 늘어나는지도 알 수 없었다.
  //
  // 이제 둘 다 숫자를 적는다(5차 531, 사용자 요청). 대신 거짓말하지 않도록
  // 서버 기본값과 어긋나지 않는지를 여기서 지킨다.
  test('뜻·발음 하루 한도는 서버(subscriptionTier.ts)와 같은 값이다', () {
    final ts = File('functions/src/subscriptionTier.ts').readAsStringSync();
    final block =
        RegExp(r'DEFAULT_ASSIST_LIMITS[^=]*=\s*\{([^}]*)\}').firstMatch(ts);
    expect(block, isNotNull, reason: '서버 쪽 기본값을 찾지 못했다');
    final body = block!.group(1)!;

    int serverValue(String key) =>
        int.parse(RegExp('$key:' r'\s*(\d+)').firstMatch(body)!.group(1)!);

    for (final tier in SubscriptionTier.values) {
      expect(dailyAssistFor(tier), serverValue(tier.name), reason: tier.name);
    }
  });

  test('예문 하루 한도도 서버(exampleQuota.ts)와 같은 값이다', () {
    final ts = File('functions/src/exampleQuota.ts').readAsStringSync();
    final block =
        RegExp(r'DEFAULT_EXAMPLE_LIMITS[^=]*=\s*\{([^}]*)\}').firstMatch(ts);
    expect(block, isNotNull, reason: '서버 쪽 기본값을 찾지 못했다');
    final body = block!.group(1)!;

    int serverValue(String key) =>
        int.parse(RegExp('$key:' r'\s*(\d+)').firstMatch(body)!.group(1)!);

    for (final tier in SubscriptionTier.values) {
      expect(dailyExamplesFor(tier), serverValue(tier.name), reason: tier.name);
    }
  });

  test('두 한도를 나눠 적고, 권유 글에는 숫자를 적지 않는다', () {
    for (final copy in subscriptionTiers) {
      expect(copy.benefits,
          contains('뜻·발음·원문 생성 하루 ${dailyAssistFor(copy.tier)}번'));
      expect(copy.benefits,
          contains('예문 생성 하루 ${dailyExamplesFor(copy.tier)}번'));
    }
    // 권유 글은 단계를 모르는 자리에서도 쓰므로 숫자를 적지 않는다.
    expect(RegExp(r'\d').hasMatch(assistQuotaUpsellText), isFalse);
  });

  test('서버 저장 한도 표기는 바이트 값과 맞는다', () {
    expect(serverStorageQuotaLabel(SubscriptionTier.light), '10GB');
    expect(serverStorageQuotaLabel(SubscriptionTier.plus), '20GB');
    expect(serverStorageQuotaLabel(SubscriptionTier.pro), '30GB');
    expect(serverStorageQuotaLabel(SubscriptionTier.max), '80GB');
  });

  test("'~에 더해' 카드에 아래 단계와 똑같은 줄은 없다", () {
    // 프로·맥스 카드가 플러스와 똑같은 '한 낱말에 예문 10개까지'를 그대로
    // 또 적고 있었다. 하나도 안 늘었는데 더 주는 것처럼 읽힌다(5차).
    for (var i = 1; i < subscriptionTiers.length; i++) {
      final lower = subscriptionTiers[i - 1].benefits.toSet();
      final same = subscriptionTiers[i]
          .benefits
          .skip(1) // 첫 줄은 '플러스에 더해'처럼 그 단계만의 말이다.
          .where(lower.contains)
          .toList();
      expect(same, isEmpty, reason: subscriptionTiers[i].tier.name);
    }
  });

  test('값이 오르는 줄은 그대로 적는다', () {
    // 겹치는 줄을 빼다가 다른 줄까지 사라지면 카드가 텅 빈다.
    for (final copy in subscriptionTiers) {
      expect(copy.benefits, contains('매달 패롯 ${monthlyParrotsFor(copy.tier)}개'),
          reason: copy.tier.name);
      expect(copy.benefits,
          contains('예문 생성 하루 ${dailyExamplesFor(copy.tier)}번'),
          reason: copy.tier.name);
    }
  });
}
