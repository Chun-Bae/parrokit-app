// 로그인한 사람 정보를 합치는 규칙(5차 385).
//
// 전에는 로그인 길마다 합치는 코드가 따로 있었고(일곱 벌), 여섯 벌이
// lastNicknameChangedAt을 빠뜨렸다. 그 길로 로그인하면 닉네임을 바꾼 날짜가
// 사라져 30일 제한이 풀린 것처럼 보였다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/repositories/app_user_merge.dart';
import 'package:parrokit/data/models/user.dart';

final _now = DateTime(2026, 11, 17, 12);

void main() {
  test('인증 → 서버 → 기기 차례로 고른다', () {
    final user = mergeAppUser(
      uid: 'u1',
      authDisplayName: '인증이름',
      authEmail: null,
      authPhotoUrl: null,
      server: const AppUser(id: 'u1', displayName: '서버이름', email: 's@x.com'),
      local: const AppUser(
          id: 'u1', displayName: '기기이름', email: 'l@x.com', photoUrl: 'local.png'),
      now: _now,
    );

    expect(user.displayName, '인증이름');
    expect(user.email, 's@x.com');
    expect(user.photoUrl, 'local.png');
    expect(user.updatedAt, _now);
  });

  test('숫자는 서버 → 기기 → 0', () {
    // AppUser의 기본값은 패롯 20·크래커 1000이라, 서버 문서가 있으면 그 값이
    // 그대로 온다. 아무 데도 없을 때만 0이다.
    final user = mergeAppUser(
      uid: 'u1',
      server: const AppUser(id: 'u1', parrots: 7, crackers: 30),
      local: const AppUser(id: 'u1', parrots: 3, crackers: 500),
      now: _now,
    );
    expect(user.parrots, 7);
    expect(user.crackers, 30);

    final onlyLocal = mergeAppUser(
      uid: 'u1',
      local: const AppUser(id: 'u1', parrots: 3, crackers: 500),
      now: _now,
    );
    expect(onlyLocal.parrots, 3);
    expect(onlyLocal.crackers, 500);

    final nothing = mergeAppUser(uid: 'u1', now: _now);
    expect(nothing.parrots, 0);
    expect(nothing.crackers, 0);
    expect(nothing.subParrots, 0);
    expect(nothing.unreadNotificationCount, 0);
    expect(nothing.blockedUserIds, isEmpty);
  });

  test('닉네임을 바꾼 날짜는 어느 길로 로그인해도 지킨다', () {
    final changed = DateTime(2026, 11, 1);
    final fromServer = mergeAppUser(
      uid: 'u1',
      server: AppUser(id: 'u1', lastNicknameChangedAt: changed),
      now: _now,
    );
    expect(fromServer.lastNicknameChangedAt, changed);

    final fromLocal = mergeAppUser(
      uid: 'u1',
      local: AppUser(id: 'u1', lastNicknameChangedAt: changed),
      now: _now,
    );
    expect(fromLocal.lastNicknameChangedAt, changed);
  });

  test('만든 날짜와 메일의 기본값은 고르게 할 수 있다', () {
    final plain = mergeAppUser(uid: 'u1', now: _now);
    expect(plain.createdAt, isNull);
    expect(plain.email, isNull);

    final signUp = mergeAppUser(
      uid: 'u1',
      createdAtDefaultsToNow: true,
      emailDefaultsToEmpty: true,
      now: _now,
    );
    expect(signUp.createdAt, _now);
    expect(signUp.email, '');
  });

  test('로그인 길마다 따로 합치지 않는다', () {
    final code =
        File('lib/core/infrastructure/repositories/user_repository.dart')
            .readAsStringSync();
    expect('mergeAppUser('.allMatches(code).length, 7);
    // 예전처럼 직접 조립하는 자리가 남아 있으면 또 빠뜨리게 된다.
    expect(code.contains('unreadNotificationCount: unreadCount'), isFalse);
  });
}
