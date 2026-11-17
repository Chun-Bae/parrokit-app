// 받아 둔 영상 화면의 빈 상태(5차 451).
//
// 전에는 '기기에 받아 둔 영상이 아직 없어요.' 한 줄뿐이라 어떻게 하면
// 생기는지도, 어디로 가야 하는지도 알 수 없었다. 지울 것이 없는데
// '지워요' 설명부터 나오기도 했다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/features/settings/more/presentation/storage_cache_management_screen.dart';

const _path =
    'lib/features/settings/more/presentation/storage_cache_management_screen.dart';

String _code() => File(_path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('빈 화면이 무엇을 하면 되는지와 갈 길을 적는다', () {
    expect(cachedEmptyTitle, '받아 둔 영상이 아직 없어요');
    expect(cachedEmptyBody, contains('한 번 보면'));
    expect(cachedEmptyActionLabel, '보관함 열기');

    final code = _code();
    expect(code, contains('cached-empty-open-library'));
    expect(code, contains('context.go(AppRoutes.collectionPath)'));
    // 영상 이야기를 했으니 클립 탭으로 연다(단어 탭이 열리면 안 된다).
    // 탭 번호를 숫자로 적으면 순서가 바뀔 때 조용히 어긋난다(5차 467).
    expect(
        code, contains('CollectionShellScreen.openTab(CollectionShellScreen.clipTab)'));
  });

  test('빈 화면에서는 지우기 설명을 먼저 하지 않는다', () {
    expect(_code(), contains('if (_items.isNotEmpty)'));
  });

  test('지우기 실패 글을 이 화면만 따로 적지 않는다', () {
    final code = _code();
    expect(code, contains('showToast(deleteFailedShortMessage)'));
    expect(code.contains("'지우지 못했어요. 다시 해 보세요.'"), isFalse);
    // 공용 글귀는 '다시 해 주세요'로 끝난다(5차).
    expect(deleteFailedShortMessage, endsWith(retryLaterSuffix));
  });

  test('다시 하라는 말이 앱의 다른 곳과 같은 꼴이다', () {
    expect(_code().contains('다시 해 보세요'), isFalse);
  });
}
