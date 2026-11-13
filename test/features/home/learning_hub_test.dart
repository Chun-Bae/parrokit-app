import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/features/collection/shell/presentation/collection_shell_screen.dart';
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

  test('보관함 탭 요청은 마지막에 본 탭과 상관없이 그 탭을 알린다', () {
    AppConfig.libraryTab = 2; // 마지막에 단어 탭을 봤다.
    final heard = <int?>[];
    void listener() => heard.add(CollectionShellScreen.requestedTab.value);
    CollectionShellScreen.requestedTab.addListener(listener);
    addTearDown(
        () => CollectionShellScreen.requestedTab.removeListener(listener));

    CollectionShellScreen.openTab(1);
    expect(AppConfig.libraryTab, 1);
    expect(heard.last, 1);
    // 같은 탭을 다시 요청해도 다시 알린다(그 사이 사용자가 탭을 바꿨을 수 있다).
    CollectionShellScreen.openTab(1);
    expect(heard.where((t) => t == 1), hasLength(2));
  });
}
