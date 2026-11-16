// 앱 테마(시스템·라이트·다크)를 들고 저장한다.
//
// 저장은 예전처럼 'themeMode' 키에 ThemeMode의 번호를 적는다. 예전에 저장한
// 값을 그대로 읽어야 하므로 키와 값의 모양은 바꾸지 않는다.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';

/// 저장 키. 예전 값과 같아야 한다.
const String themeModePrefKey = 'themeMode';

/// 저장된 번호를 ThemeMode로 읽는다. 모르는 번호면 시스템을 따른다(5차 373).
///
/// 전에는 `ThemeMode.values[번호]`라 번호가 범위를 벗어나면 앱이 켜지다 말고
/// 멈출 수 있었다(값이 깨졌거나 앞으로 모드가 줄어드는 경우).
ThemeMode themeModeFromPref(int? stored) {
  if (stored == null || stored < 0 || stored >= ThemeMode.values.length) {
    return ThemeMode.system;
  }
  return ThemeMode.values[stored];
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeMode = themeModeFromPref(prefs.getInt(themeModePrefKey));
    } catch (error) {
      // 못 읽으면 시스템 테마로 둔다. 테마 하나 때문에 앱이 안 켜지면 안 된다.
      AppLogger.w('[Theme] 테마를 읽지 못했어요: $error');
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(themeModePrefKey, mode.index);
    } catch (error) {
      // 이번 실행에는 바뀐 테마를 쓰고, 다음에 다시 저장해 본다.
      AppLogger.w('[Theme] 테마를 저장하지 못했어요: $error');
    }
  }
}
