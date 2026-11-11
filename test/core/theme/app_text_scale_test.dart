import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

void main() {
  // 스케일에 들어 있는 크기만 쓰기로 했으므로, 테마가 그 크기들을 그대로
  // 들고 있는지 확인한다. 값이 흔들리면 화면들이 다시 fontSize를 적게 된다.
  const expected = <String, double>{
    'labelSmall': 11,
    'bodySmall': 12,
    'labelMedium': 13,
    'bodyMedium': 14,
    'labelLarge': 14,
    'bodyLarge': 15,
    'titleMedium': 16,
    'titleLarge': 18,
    'headlineSmall': 20,
    'headlineMedium': 24,
    'headlineLarge': 32,
    'displaySmall': 52,
  };

  Map<String, TextStyle?> slots(TextTheme t) => {
        'labelSmall': t.labelSmall,
        'bodySmall': t.bodySmall,
        'labelMedium': t.labelMedium,
        'bodyMedium': t.bodyMedium,
        'labelLarge': t.labelLarge,
        'bodyLarge': t.bodyLarge,
        'titleMedium': t.titleMedium,
        'titleLarge': t.titleLarge,
        'headlineSmall': t.headlineSmall,
        'headlineMedium': t.headlineMedium,
        'headlineLarge': t.headlineLarge,
        'displaySmall': t.displaySmall,
      };

  for (final (label, theme) in [
    ('라이트', AppTheme.light),
    ('다크', AppTheme.dark),
  ]) {
    test('$label 테마의 타이포 슬롯이 스케일 크기를 쓴다', () {
      final actual = slots(theme.textTheme);
      for (final entry in expected.entries) {
        expect(actual[entry.key]?.fontSize, entry.value,
            reason: '${entry.key}의 크기');
      }
    });
  }

  testWidgets('context.texts는 테마 슬롯을 그대로 돌려준다', (tester) async {
    late AppTexts texts;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(builder: (context) {
        texts = context.texts;
        return const SizedBox();
      }),
    ));
    expect(texts.titleLarge.fontSize, 18);
    expect(texts.labelSmall.fontSize, 11);
    expect(texts.headlineLarge.fontWeight, FontWeight.w900);
  });

  test('슬롯이 빈 TextTheme에서는 스케일 기본값으로 떨어진다', () {
    // ThemeData는 비워둔 슬롯을 Typography 기본값으로 채우므로 여기서는
    // AppTexts에 빈 TextTheme을 직접 넣어 떨어지는 값만 확인한다.
    const texts = AppTexts(TextTheme());
    expect(texts.titleLarge.fontSize, AppTextScale.titleLarge.fontSize);
    expect(texts.bodySmall.fontSize, AppTextScale.bodySmall.fontSize);
    expect(texts.labelSmall.fontWeight, FontWeight.w700);
  });
}
