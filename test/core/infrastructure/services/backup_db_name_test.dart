// 백업이 실제 데이터베이스 파일을 가리키는지 지킨다(5차 566).
//
// 'paro.db'로 적혀 있었는데 앱이 여는 파일은 app.db다. 그래서 백업은
// DB 갈래를 한 번도 타지 않았고, manifest에는 담지도 않은 이름이 적혔다.
// 클립이 살아남은 건 미디어 훑기가 Documents 전체를 쓸어 담은 덕이다.
//
// 가장 나쁜 것은 복원 안전망이 꺼져 있던 것이다. 복원 전에 지금 DB를
// 복사해 두는 코드가 없는 파일을 찾다 넘어가, 복원이 엎어지면 되돌릴
// 길이 없었다(5차 387에서 넣은 보호).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/backup_service.dart';

void main() {
  final service =
      File('lib/core/infrastructure/services/backup_service.dart')
          .readAsStringSync();
  final database = File('lib/data/local/app_database.dart').readAsStringSync();

  test('백업이 쓰는 이름이 앱이 여는 파일과 같다', () {
    // app_database.dart가 'app.db'를 연다. 둘이 어긋나면 안 된다.
    expect(database, contains("'app.db'"));
    expect(BackupService.instance.dbRelativePath, 'app.db');
  });

  test('예전 이름도 되돌릴 수 있게 들고 있다', () {
    expect(BackupService.legacyDbRelativePath, 'paro.db');
    // 복원에서 예전 이름을 함께 찾는다.
    expect(service, contains('legacyDbRelativePath'));
  });

  test('찌꺼기 청소가 두 이름을 다 본다', () {
    final clean = service.substring(service.indexOf('cleanRestoreLeftovers'));
    expect(clean, contains('\$dbRelativePath.bak_'));
    expect(clean, contains('\$legacyDbRelativePath.bak_'));
  });
}
