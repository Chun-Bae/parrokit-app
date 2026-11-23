// 코인을 사는 흐름의 안내를 한 곳에서만 적는다(5차 425).
//
// 같은 흐름이 두 곳에 있다(더보기 코인 상품 목록, RevenueCat 페이월).
// 돈이 오가는 자리라 말이 갈리면 안 된다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/sections/coin_purchase_text.dart';

const _home =
    'lib/features/settings/more/presentation/sections/coin_purchase_text.dart';
const _store =
    'lib/features/settings/more/presentation/sections/coin_store_section.dart';
const _paywall =
    'lib/features/settings/more/presentation/sections/payment_section.dart';

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('결제 안내를 다른 파일이 손으로 적지 않는다', () {
    final texts = [
      productLoadFailedMessage,
      paymentFailedMessage,
      coinsAddedMessage(100),
      coinsComingMessage(100),
    ];
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      if (file.path.endsWith(_home)) continue;
      final code = _code(file.path);
      for (final text in texts) {
        if (code.contains("'$text'")) offenders.add('${file.path}: $text');
      }
      if (code.contains("코인이 충전됐어요")) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: '$_home에서 꺼내 쓴다\n${offenders.join('\n')}');
  });

  test('두 곳이 같은 글귀를 쓴다', () {
    for (final path in [_store, _paywall]) {
      final code = _code(path);
      expect(code, contains('coinsComingMessage('), reason: path);
      expect(code, contains('paymentFailedMessage'), reason: path);
    }
  });

  // 앱이 직접 넣던 때는 영수증을 확인하는 곳이 없어서, 결제를 거치지 않고
  // 자기 문서의 parrots를 올려도 그대로 패롯이 됐다. 패롯은 Whisper·Gemini·
  // R2를 쓰는 값이라 그만큼 서버 비용이 나간다(5차 568).
  test('결제 화면이 스스로 패롯을 넣지 않는다', () {
    for (final path in [_store, _paywall]) {
      final code = _code(path);
      expect(code.contains('addCoins('), isFalse, reason: path);
      expect(code.contains('addParrots('), isFalse, reason: path);
    }
  });

  test('지급은 곧 들어온다고 말한다', () {
    expect(coinsComingMessage(88), contains('88'));
    expect(coinsComingMessage(88), contains('곧'));
  });
}
