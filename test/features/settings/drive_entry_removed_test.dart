// Google Drive 저장은 더 쓰지 않는다(5차). 새로 연동하는 길이 화면에 없어야
// 하고, 이미 연동한 사람에게는 해제만 남는다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _storageSheet =
    'lib/features/settings/more/presentation/sections/remote_storage_section.dart';
const _dataSection =
    'lib/features/settings/more/presentation/sections/data_section.dart';
const _libraryFolder =
    'lib/features/collection/library/presentation/sections/library_folder_section.dart';

void main() {
  test('새로 연동하는 버튼이 없다', () {
    final code = _code(_storageSheet);
    expect(code, isNot(contains('구글 드라이브 연동하기')));
    expect(code, isNot(contains('provider.connectGoogleDrive()')));
  });

  test('이미 연동한 사람에게만 Drive 칸과 해제를 보여 준다', () {
    final code = _code(_storageSheet);
    expect(code, contains("if (context.watch<ClipProvider>().hasGoogleDriveLinked)"));
    expect(code, contains("const Text('연동 해제')"));
    expect(code, contains('provider.disconnectGoogleDrive()'));
  });

  test('보관함 저장 공간 카드에도 새로 연동하는 길이 없다', () {
    // 더보기 시트에서만 뺐더니 보관함 카드에 '구글 드라이브 연동하기'가 남아
    // 있었다. 없어진 기능을 누를 수 있게 두면 안 된다.
    final code = _code(_libraryFolder);
    expect(code, isNot(contains('구글 드라이브 연동하기')));
    expect(code, isNot(contains('provider.connectGoogleDrive()')));
    expect(code, contains('if (isLinked)'));
    expect(code, contains('provider.disconnectGoogleDrive()'));
  });

  test("기기에 둔 파일을 '로컬'이라 부르지 않는다", () {
    // 저장 칩과 '받아 둔 영상' 화면은 '이 기기'로 바꿨는데, 보관함 카드 제목과
    // Drive 해제 진행 글만 앱 안쪽 말이 남아 있었다.
    for (final path in [
      _libraryFolder,
      'lib/core/state/provider/clip_provider.dart',
      'lib/core/domain/collection_clip/data/repositories/clip_migration_repository_impl.dart',
    ]) {
      for (final line in File(path).readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        // 사람에게 보이는 글(따옴표 안)에만 해당한다. 변수·상수 이름은 둔다.
        for (final match in RegExp(r"'[^']*'").allMatches(line)) {
          final text = match.group(0)!;
          if (!RegExp(r'[가-힣]').hasMatch(text)) continue;
          expect(text.contains('로컬'), isFalse, reason: '$path: $text');
        }
      }
    }
  });

  test('더보기 줄 제목에서 Google Drive를 뺐다', () {
    final code = _code(_dataSection);
    expect(code, contains("title: '저장 용량'"));
    expect(code, isNot(contains("'저장 용량 · Google Drive'")));
    // 연동이 남아 있는 사람에게만 그 사실을 적는다.
    expect(code, contains("if (driveLinked)"));
  });
}
