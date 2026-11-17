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
      coinsNotGivenMessage,
      coinsAddedMessage(100),
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
      expect(code, contains('coinsAddedMessage('), reason: path);
      expect(code, contains('paymentFailedMessage'), reason: path);
      expect(code, contains('coinsNotGivenMessage'), reason: path);
    }
  });

  test('코인이 들어간 뒤에만 충전됐다고 말한다', () {
    // 전에는 페이월에서 '충전됐어요!'를 try 밖에서 띄웠다. 지급이 넘어지면
    // '지급에 실패했어요'와 '충전됐어요!'가 함께 떠서, 돈을 낸 사람이
    // 받았는지 못 받았는지 알 수 없었다.
    final code = _code(_paywall);
    final addIndex = code.indexOf('await widget.userProvider.addCoins(');
    final okIndex = code.indexOf('showToast(coinsAddedMessage(');
    final catchIndex = code.indexOf('} catch (e) {', addIndex);
    expect(addIndex, greaterThan(-1));
    expect(okIndex, greaterThan(addIndex));
    expect(okIndex, lessThan(catchIndex));
  });

  test('돈만 나가는 경우를 사용자에게 말한다', () {
    expect(coinsNotGivenMessage, contains('결제는 됐지만'));
    expect(coinsNotGivenMessage, contains('문의'));
  });
}
