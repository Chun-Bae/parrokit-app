// 보관함 탭 순서는 문장 - 단어 - 클립이다(5차 467, 사용자 결정).
//
// 순서를 바꾸면 openTab(1)처럼 숫자를 적어 둔 자리가 조용히 다른 탭을
// 열게 된다. 그래서 자리마다 이름을 두고, 부르는 쪽이 그 이름을 쓰는지
// 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/collection_shell_screen.dart';

String _sourceOf(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('탭 자리가 문장 - 단어 - 클립이다', () {
    expect(CollectionShellScreen.sentenceTab, 0);
    expect(CollectionShellScreen.wordTab, 1);
    expect(CollectionShellScreen.clipTab, 2);
  });

  test('탭 줄과 내용이 같은 차례다', () {
    final src = _sourceOf(
        'lib/features/collection/shell/presentation/collection_shell_screen.dart');
    final labels = [
      src.indexOf("label: '문장'"),
      src.indexOf("label: '단어'"),
      src.indexOf("label: '클립'"),
    ];
    expect(labels, orderedEquals(List.of(labels)..sort()));

    final bodies = [
      src.indexOf('SentenceCollectionPreview('),
      src.indexOf('WordCollectionPreview('),
      src.indexOf('ClipLibraryHome('),
    ];
    for (final at in bodies) {
      expect(at, greaterThan(-1));
    }
    expect(bodies, orderedEquals(List.of(bodies)..sort()),
        reason: '내용 차례가 탭 줄과 달라지면 엉뚱한 탭이 열린다');
  });

  test('다른 화면이 탭 번호를 숫자로 적지 않는다', () {
    const callers = [
      'lib/features/settings/more/presentation/storage_cache_management_screen.dart',
      'lib/features/home/dashboard/presentation/character_dashboard_screen.dart',
      'lib/features/home/dashboard/presentation/learning_hub_screen.dart',
      'lib/features/collection/library/presentation/clip_discover_screen.dart',
    ];
    final numeric = RegExp(r'CollectionShellScreen\.openTab\(\s*\d');
    for (final path in callers) {
      expect(numeric.hasMatch(_sourceOf(path)), isFalse,
          reason: '$path: 숫자 대신 sentenceTab/wordTab/clipTab을 쓴다');
    }
  });
}
