import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/features/home/dashboard/presentation/learning_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('따라 말하기는 전체 재생에서 자막 한 줄마다 멈추게 연다', () async {
    await applyStudyMode(0);
    expect(AppConfig.segmentLoop, isTrue, reason: '전체 재생');
    expect(AppConfig.pauseEachLine, isTrue);
    expect(AppConfig.repeatAll, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pauseEachLine'), isTrue);
  });

  test('반복 듣기는 구간 재생에서 구간을 반복하게 연다', () async {
    await applyStudyMode(1);
    expect(AppConfig.segmentLoop, isFalse, reason: '구간 재생');
    expect(AppConfig.pauseEachLine, isFalse);
    expect(AppConfig.repeatAll, isTrue);
  });
}
