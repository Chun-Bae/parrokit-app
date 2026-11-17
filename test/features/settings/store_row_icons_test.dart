// 상품 줄(구독·광고 제거)의 그림이 실제로 있는 파일을 가리키는지 본다(5차 465).
//
// 경로를 잘못 적으면 화면에서 그림만 조용히 안 뜬다. analyze도 테스트도
// 잡아 주지 않아, 기기를 봐야만 알 수 있었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/sections/ads_removal_section.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/features/settings/subscription/presentation/subscription_texts.dart';

void main() {
  test('상품 줄 그림이 모두 있는 파일이다', () {
    final paths = <String>{
      adsRemovalIconAsset,
      for (final tier in SubscriptionTier.values) subscriptionTierIconAsset(tier),
    };
    expect(paths.length, 4, reason: '단계마다 다른 그림이어야 한다');
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: '$path 가 없다');
    }
  });

  test('pubspec이 그림이 든 칸을 담는다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('- assets/icons/'), isTrue);
  });

  test('더보기의 상품 칸 이름이 그 안의 줄 이름과 겹치지 않는다', () {
    final src = File('lib/features/settings/more/presentation/more_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(src.contains("_GroupLabel('상품')"), isTrue);
    expect(src.contains("_GroupLabel('구독')"), isFalse);
  });
}
