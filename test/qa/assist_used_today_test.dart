// 서버가 주는 remainingToday에는 사 둔 몫이 더해져 있다(5차 546).
//
// 한도에서 그냥 빼면 하루치를 다 쓴 사람도 '오늘 2/3회'로 보인다. 기기에서
// 더보기 카드는 '3 / 3번 +1', 문장 추가 앱바는 '오늘 2/3회 사용'이라고
// 같은 수를 다르게 말했다. 그 말을 믿고 누르면 돈 주고 산 몫이 깎였다.
//
// 세 화면이 한 함수를 쓰게 모았으니, 다시 갈라지지 않는지 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';

void main() {
  group('오늘 쓴 횟수', () {
    test('사 둔 몫은 빼고 하루치만 센다', () {
      // 한도 3, 하루치를 다 씀, 사 둔 몫 1 → remaining = 0 + 1 = 1
      expect(assistUsedToday(limit: 3, remaining: 1, credits: 1), 3);
    });

    test('사 둔 몫이 없으면 그냥 뺀 값이다', () {
      expect(assistUsedToday(limit: 3, remaining: 1), 2);
    });

    test('아직 모르면 null이다', () {
      expect(assistUsedToday(limit: null, remaining: 1), isNull);
      expect(assistUsedToday(limit: 3, remaining: null), isNull);
    });

    test('한도 밖으로 나가지 않는다', () {
      expect(assistUsedToday(limit: 3, remaining: 9), 0);
      expect(assistUsedToday(limit: 3, remaining: 0, credits: 9), 3);
    });
  });

  group('다 썼나', () {
    test('하루치를 다 써도 사 둔 몫이 있으면 쓸 수 있다', () {
      expect(assistExhausted(used: 3, limit: 3, credits: 1), isFalse);
    });

    test('둘 다 없으면 막는다', () {
      expect(assistExhausted(used: 3, limit: 3), isTrue);
    });

    test('모르면 막지 않는다', () {
      expect(assistExhausted(used: null, limit: 3), isFalse);
    });
  });

  // 같은 셈을 화면마다 따로 적으면 또 갈라진다.
  test('세 화면이 모두 한 함수를 쓴다', () {
    const paths = [
      'lib/core/content/add_sentence_controller.dart',
      'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
      'lib/features/settings/more/presentation/sections/assist_usage_section.dart',
    ];
    for (final path in paths) {
      final src = File(path).readAsStringSync();
      expect(src.contains('assistUsedToday'), isTrue, reason: path);
    }
  });
}
