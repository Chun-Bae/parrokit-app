// 쇼츠에서 전면 광고가 뜨는 동안 영상은 멈춰 있어야 한다(5차 372).
//
// 전에는 showInterstitialAd() 바로 다음 줄에서 멈춤을 풀었다. 광고는 그제야
// 올라오니 광고를 보는 내내 뒤에서 영상 소리가 났다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('광고가 닫힌 뒤에 다시 튼다', () {
    final code = _read(
        'lib/features/collection/clip/shorts/presentation/shorts_screen.dart');
    expect(code, contains('showInterstitialAd(onClosed:'));
    // 광고를 띄우자마자 푸는 줄이 남아 있으면 안 된다.
    expect(
        code.contains('showInterstitialAd();\n      ad.recordAdShown();'),
        isFalse);
  });

  test('AdService는 닫힘을 알려 준다', () {
    final code = _read('lib/core/infrastructure/services/ad_service.dart');
    expect(code, contains('void showInterstitialAd({VoidCallback? onClosed})'));
    // 준비된 광고가 없어 그냥 지나갈 때도 알려야 멈춤이 풀린다.
    expect(code, contains('''    if (ad == null) {
      load();
      onClosed?.call();
      return;
    }'''));
    // 닫힘·실패 둘 다에서 알린다.
    expect('onClosed?.call();'.allMatches(code).length, greaterThanOrEqualTo(3));
  });
}
