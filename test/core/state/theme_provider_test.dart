// 테마 저장·읽기(5차 373).
//
// 저장된 번호가 범위를 벗어나면 `ThemeMode.values[번호]`가 예외를 냈다.
// 앱을 켜는 길에 있는 코드라 그러면 켜지다 멈춘다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('저장된 값이 없으면 시스템을 따른다', () {
    expect(themeModeFromPref(null), ThemeMode.system);
  });

  test('번호대로 읽는다', () {
    expect(themeModeFromPref(0), ThemeMode.system);
    expect(themeModeFromPref(1), ThemeMode.light);
    expect(themeModeFromPref(2), ThemeMode.dark);
  });

  test('모르는 번호면 시스템을 따른다(멈추지 않는다)', () {
    expect(themeModeFromPref(-1), ThemeMode.system);
    expect(themeModeFromPref(99), ThemeMode.system);
  });

  test('예전에 저장한 다크를 그대로 읽는다', () async {
    SharedPreferences.setMockInitialValues({themeModePrefKey: 2});
    final provider = ThemeProvider();
    await provider.loadTheme();
    expect(provider.themeMode, ThemeMode.dark);
  });

  test('깨진 값이 저장돼 있어도 켜진다', () async {
    SharedPreferences.setMockInitialValues({themeModePrefKey: 7});
    final provider = ThemeProvider();
    await provider.loadTheme();
    expect(provider.themeMode, ThemeMode.system);
  });

  test('고르면 바로 바뀌고 같은 키에 저장된다', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setTheme(ThemeMode.light);
    expect(provider.themeMode, ThemeMode.light);
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(themeModePrefKey), ThemeMode.light.index);
  });
}
