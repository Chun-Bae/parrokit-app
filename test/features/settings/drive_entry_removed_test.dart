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

  test('더보기 줄 제목에서 Google Drive를 뺐다', () {
    final code = _code(_dataSection);
    expect(code, contains("title: '저장 용량'"));
    expect(code, isNot(contains("'저장 용량 · Google Drive'")));
    // 연동이 남아 있는 사람에게만 그 사실을 적는다.
    expect(code, contains("if (driveLinked)"));
  });
}
