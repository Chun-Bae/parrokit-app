import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/app/router/app_router.dart';

void main() {
  String? go(String location,
          {bool loggedIn = true, bool hasNickname = true}) =>
      authRedirectFor(
          location: location, loggedIn: loggedIn, hasNickname: hasNickname);

  group('로그인 전', () {
    test('앱 화면은 로그인 화면으로 보낸다', () {
      expect(go('/dashboard', loggedIn: false), '/auth/sign-in');
      expect(go('/community', loggedIn: false), '/auth/sign-in');
      expect(go('/onboarding', loggedIn: false), '/auth/sign-in');
    });

    test('로그인·가입·소개 화면은 그대로 둔다', () {
      expect(go('/auth/sign-in', loggedIn: false), isNull);
      expect(go('/auth/sign-up', loggedIn: false), isNull);
      expect(go('/intro', loggedIn: false), isNull);
    });

    test("'/auth'만 치면 로그인 화면으로", () {
      expect(go('/auth', loggedIn: false), '/auth/sign-in');
    });
  });

  group('로그인했는데 닉네임이 없을 때', () {
    test('어디로 가든 온보딩으로 보낸다(로그인 화면 포함)', () {
      expect(go('/dashboard', hasNickname: false), '/onboarding');
      expect(go('/auth/sign-in', hasNickname: false), '/onboarding');
      expect(go('/community', hasNickname: false), '/onboarding');
    });

    test('온보딩 화면은 그대로 둔다', () {
      expect(go('/onboarding', hasNickname: false), isNull);
    });
  });

  group('로그인하고 닉네임도 있을 때', () {
    test('온보딩·로그인 화면에 있으면 홈으로', () {
      expect(go('/onboarding'), '/dashboard');
      expect(go('/auth/sign-in'), '/dashboard');
      expect(go('/auth'), '/dashboard');
    });

    test('앱 화면은 그대로 둔다(쿼리가 있어도)', () {
      expect(go('/dashboard'), isNull);
      expect(go('/collection/clips/play?clipId=3'), isNull);
    });
  });

  test("'/'는 늘 홈으로", () {
    expect(go('/'), '/dashboard');
    expect(go('/', loggedIn: false), '/dashboard');
  });
}
