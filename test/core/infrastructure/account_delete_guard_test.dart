// 탈퇴를 시작해도 되는지 먼저 보는 규칙(5차 386).
//
// 전에는 사용자 문서를 먼저 지우고 계정을 지웠다. 계정 삭제는 로그인한 지
// 오래되면 거절되는데, 그때는 문서만 사라지고 계정은 남아 자료를 잃는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/repositories/account_delete_guard.dart';

final _now = DateTime(2026, 11, 17, 12);

void main() {
  test('방금 로그인했으면 바로 탈퇴할 수 있다', () {
    expect(
        needsRecentLoginToDelete(
            _now.subtract(const Duration(minutes: 1)), _now),
        isFalse);
  });

  test('오래됐으면 다시 로그인해야 한다', () {
    expect(
        needsRecentLoginToDelete(
            _now.subtract(const Duration(minutes: 30)), _now),
        isTrue);
  });

  test('언제 로그인했는지 모르면 멈춘다', () {
    expect(needsRecentLoginToDelete(null, _now), isTrue);
  });

  test('보는 시간은 바꿔 줄 수 있다', () {
    final at = _now.subtract(const Duration(minutes: 10));
    expect(needsRecentLoginToDelete(at, _now, window: const Duration(hours: 1)),
        isFalse);
  });

  test('멈출 때는 다시 로그인하라고 말한다', () {
    expect(recentLoginNeededMessage, contains('다시 로그인'));
  });

  test('탈퇴는 지우기 전에 이 검사를 먼저 한다', () {
    final code =
        File('lib/core/infrastructure/repositories/user_repository.dart')
            .readAsStringSync();
    final guard = code.indexOf('needsRecentLoginToDelete(');
    final deleteDoc = code.indexOf('deleteUserDocument(');
    expect(guard, greaterThan(0));
    expect(guard, lessThan(deleteDoc));
  });
}
