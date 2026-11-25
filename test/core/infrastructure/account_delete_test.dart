// 탈퇴가 중간에 끊겨도 반쪽으로 남지 않는다(5차, 사용자 요청).
//
// 전에는 앱이 ①users 문서 삭제 → ②Auth 계정 삭제를 했다. ②는 로그인한 지
// 오래되면 'requires-recent-login'으로 거절되고, 그러면 **문서는 없는데
// 계정은 살아 있는** 상태가 남았다. 다시 들어가면 온보딩으로 가는데 학습
// 기록은 이미 사라진 뒤다. 그걸 막으려고 "최근에 로그인했나"를 미리 재는
// 가드를 뒀지만, 그 가드는 오래 켜 둔 사람의 탈퇴를 아예 막아 버렸다.
//
// 이제 서버(functions/src/accountDelete.ts)가 Admin SDK로 지운다.
// Admin SDK는 재로그인을 요구하지 않고, **계정을 맨 마지막에** 지우므로
// 중간에 끊겨도 계정이 남아 다시 부를 수 있다. 각 단계는 멱등이다.
//
// 이 거울 테스트는 그 순서가 다시 뒤집히지 않게 지킨다. 순서가 뒤집히면
// 남은 문서를 치울 주인이 사라진다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('서버가 지우는 순서', () {
    late String code;

    setUp(() {
      code = File('functions/src/accountDelete.ts').readAsStringSync();
    });

    test('Auth 계정을 맨 마지막에 지운다', () {
      final nickname = code.indexOf('releaseNickname(');
      final docs = code.indexOf('recursiveDelete(');
      final auth = code.indexOf('deleteUser(');

      expect(nickname, greaterThan(-1), reason: '닉네임 선점을 푼다');
      expect(docs, greaterThan(-1), reason: '문서와 하위 컬렉션을 지운다');
      expect(auth, greaterThan(-1), reason: '계정을 지운다');

      // 호출 순서가 곧 안전 장치다.
      expect(docs, lessThan(auth),
          reason: '계정을 먼저 지우면 남은 문서를 치울 주인이 없다');
      expect(nickname, lessThan(auth));
    });

    test('하위 컬렉션까지 지운다', () {
      // 문서만 지우면 추천·스크랩·댓글 좋아요·투표 기록이 주인 없이 남는다.
      // Firestore는 부모를 지워도 하위를 지우지 않는다.
      expect(code, contains('recursiveDelete'));
    });

    test('이미 지워진 계정은 끝난 것으로 본다', () {
      // 앞 단계가 끊겨 다시 불렀을 때 여기서 던지면 영영 못 끝낸다.
      expect(code, contains('auth/user-not-found'));
    });

    test('로그인한 사람만 부를 수 있다', () {
      expect(code, contains('unauthenticated'));
      expect(code, contains('request.auth?.uid'));
    });
  });

  group('앱 쪽', () {
    late String repo;

    setUp(() {
      repo = File('lib/core/infrastructure/repositories/user_repository.dart')
          .readAsStringSync();
    });

    test('앱이 직접 지우지 않는다', () {
      final body = repo.substring(repo.indexOf('Future<void> deleteAccount()'));
      final end = body.indexOf('\n  }');
      final deleteAccount = body.substring(0, end);

      expect(deleteAccount, contains('_firebaseUserService.deleteAccount()'),
          reason: '서버에 맡긴다');
      expect(deleteAccount.contains('deleteUserDocument('), isFalse,
          reason: '앱이 문서를 먼저 지우면 반쪽으로 남던 그 버그가 돌아온다');
      expect(deleteAccount.contains('_authService.deleteAccount()'), isFalse,
          reason: '계정 삭제도 서버가 한다(재로그인을 요구하지 않는다)');
    });

    test('재로그인 가드는 더 쓰지 않는다', () {
      // Admin SDK는 재로그인을 요구하지 않으므로, 그 가드는 멀쩡한 탈퇴만
      // 막는다. 파일째 지웠다.
      expect(repo.contains('needsRecentLoginToDelete'), isFalse);
      expect(
          File('lib/core/infrastructure/repositories/account_delete_guard.dart')
              .existsSync(),
          isFalse);
    });
  });
}
