// 더보기 > '앱' 칸의 줄들은 같은 자리에서 시작해야 한다.
// 예전에는 '연습 알림'만 ListTile이라 아이콘과 글자가 오른쪽으로 더
// 들어가 있었다(5차).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _reminder =
    'lib/features/settings/more/presentation/widgets/practice_reminder_tile.dart';
const _theme = 'lib/features/settings/more/presentation/widgets/theme_tile.dart';
const _switch =
    'lib/features/settings/more/presentation/widgets/switch_tile.dart';

void main() {
  _nativePlayerSwitchTests();

  test('세 줄 모두 같은 LeadingIcon을 쓴다', () {
    for (final path in [_reminder, _theme, _switch]) {
      final code = _code(path);
      expect(code, contains('LeadingIcon(icon:'), reason: path);
    }
    // 연습 알림만 쓰던 40x40 직접 만든 아이콘 상자는 없앴다.
    expect(_code(_reminder).contains('width: 40,'), isFalse);
    expect(_code(_reminder).contains('ListTile('), isFalse);
  });

  test('아이콘과 글자 사이가 세 줄 모두 같다', () {
    for (final path in [_reminder, _theme, _switch]) {
      expect(_code(path), contains('SizedBox(width: AppSpacing.md)'),
          reason: path);
    }
    // 테마 줄만 쓰던 어긋난 값.
    expect(_code(_theme).contains('AppSpacing.sm + 2'), isFalse);
  });
}

void _nativePlayerSwitchTests() {
  test('새 플레이어는 늘 켜져 있고 스위치가 없다', () {
    // 사용자가 확인하고 기본으로 쓰기로 정했다(2026-11-16). 설정값을 없앴다.
    final app = _code(
        'lib/features/settings/more/presentation/sections/app_settings_section.dart');
    expect(app.contains('dev-native-player-switch'), isFalse);
    expect(app.contains('새 플레이어로 재생'), isFalse);

    final config = _code('lib/core/app/config/app_config.dart');
    expect(config.contains('nativePlayer'), isFalse,
        reason: '껐다 켜는 값이 아니다');

    final screen = _code(
        'lib/features/collection/clip/player/presentation/clip_player_screen.dart');
    expect(screen, contains('final useNative = nativePlayerSupported;'));
  });
}
