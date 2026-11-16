// 사용자 로컬 캐시(5차 374).
//
// 부트스트랩은 SharedPreferences를 열지 못하면 저장소 없는 UserPrefs를 쓴다.
// 전에는 거기에 `null as dynamic`을 넘겨서, 읽거나 쓰는 순간 앱이 멈췄다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/data/local/prefs/user_prefs.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('저장소가 없으면 비어 있는 것으로 보고, 쓰기는 조용히 넘어간다', () async {
    final prefs = UserPrefs(null);
    expect(prefs.loadUser(), isNull);
    await prefs.saveUser(const AppUser(id: 'u1'));
    await prefs.clear();
  });

  test('저장한 사람을 그대로 읽는다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SharedPreferences.getInstance();
    final prefs = UserPrefs(store);

    await prefs.saveUser(const AppUser(
      id: 'u1',
      displayName: '춘배',
      email: 'a@b.c',
      parrots: 4,
      crackers: 44900,
    ));

    final loaded = prefs.loadUser()!;
    expect(loaded.id, 'u1');
    expect(loaded.displayName, '춘배');
    expect(loaded.parrots, 4);
    expect(loaded.crackers, 44900);
    // 저장 키는 예전 그대로여야 예전에 저장한 것을 읽는다.
    expect(store.getString('user.id'), 'u1');
  });

  test('지우면 다시 없는 사람이 된다', () async {
    SharedPreferences.setMockInitialValues({'user.id': 'u1'});
    final store = await SharedPreferences.getInstance();
    final prefs = UserPrefs(store);
    expect(prefs.loadUser(), isNotNull);
    await prefs.clear();
    expect(prefs.loadUser(), isNull);
  });

  test('부트스트랩은 저장소가 없을 때 null을 넘긴다', () {
    final code =
        File('lib/core/app/bootstrap/bootstrap_dependencies.dart')
            .readAsStringSync();
    expect(code, contains('UserPrefs(null)'));
    // 주석을 뺀 코드에 `null as dynamic`이 남아 있으면 안 된다.
    final body = code
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(body.contains('null as dynamic'), isFalse);
  });
}
