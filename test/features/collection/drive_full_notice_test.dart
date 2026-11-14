// Drive 남은 공간 안내(5차). 가득 찼을 때만 경고가 보여야 한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shared/drive_full_notice.dart';

void main() {
  test('남은 공간을 모르면 안내하지 않는다', () {
    expect(driveSpaceWarning(hasQuota: false, remaining: 0), isNull);
  });

  test('가득 찼으면 올릴 수 없다고 알린다', () {
    final message = driveSpaceWarning(hasQuota: true, remaining: 0);
    expect(message, contains('가득 찼어요'));
    expect(message, contains('올릴 수 없어요'));
  });

  test('조금 남았으면 큰 클립이 안 될 수 있다고 알린다', () {
    expect(driveSpaceWarning(hasQuota: true, remaining: 1024 * 1024),
        contains('얼마 없어요'));
    // 경계: 20MB보다 적으면 알리고, 그 이상이면 알리지 않는다.
    expect(driveSpaceWarning(hasQuota: true, remaining: driveLowSpaceBytes - 1),
        isNotNull);
    expect(driveSpaceWarning(hasQuota: true, remaining: driveLowSpaceBytes),
        isNull);
  });

  test('공간이 넉넉하면 아무 말도 하지 않는다', () {
    expect(
        driveSpaceWarning(hasQuota: true, remaining: 5 * 1024 * 1024 * 1024),
        isNull);
  });
}
