// 다크 대화상자 배경이 화면 바탕과 같아 가장자리가 안 보이던 것(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';

void main() {
  test('다크 대화상자 배경은 화면 바탕과 다르고, 라이트는 그대로 바탕색', () {
    final dark = AppTheme.dark;
    expect(dark.dialogTheme.backgroundColor, isNot(dark.scaffoldBackgroundColor));
    final light = AppTheme.light;
    expect(light.dialogTheme.backgroundColor, light.colorScheme.surface);
  });
}
