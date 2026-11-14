import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:parrokit/core/app/router/app_router.dart';
import 'package:parrokit/core/app/router/app_shell.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

class _User extends Fake implements UserProvider {
  @override
  final ChangeNotifier routerRefreshNotifier = ChangeNotifier();
}

void main() {
  group('탭 칸 고르기', () {
    test('탭마다 제 칸이 켜진다', () {
      expect(appShellTabIndex(AppRoutes.explorePath), 0);
      expect(appShellTabIndex(AppRoutes.communityPath), 1);
      expect(appShellTabIndex(AppRoutes.dashboardPath), 2);
      expect(appShellTabIndex(AppRoutes.collectionPath), 3);
      expect(appShellTabIndex(AppRoutes.morePath), 4);
    });

    test('탭 안쪽 화면도 그 탭 칸을 켜 둔다', () {
      expect(appShellTabIndex('/community/board/abc'), 1);
      expect(appShellTabIndex('/community/notification'), 1);
      expect(appShellTabIndex('/collection/clip'), 3);
      expect(appShellTabIndex('/more/profile_edit'), 4);
      // 학습 허브는 홈 아래에 있다.
      expect(appShellTabIndex(AppRoutes.learningHubPath), 2);
    });

    test('모르는 경로는 홈으로 둔다', () {
      expect(appShellTabIndex('/'), 2);
      expect(appShellTabIndex('/no-such-place'), 2);
    });
  });

  group('탭 바를 숨기는 곳', () {
    test('전체 화면으로 쓰는 화면에서는 숨긴다', () {
      expect(appShellHidesNavBar('/clips/play'), isTrue);
      expect(appShellHidesNavBar('/clips/create'), isTrue);
      expect(appShellHidesNavBar(AppRoutes.recentsPath), isTrue);
      expect(appShellHidesNavBar(AppRoutes.contentStudioBridgePath), isTrue);
      expect(appShellHidesNavBar('${AppRoutes.contentStudioBridgePath}/tts'),
          isTrue);
    });

    test('탭 화면에서는 보인다', () {
      expect(appShellHidesNavBar(AppRoutes.dashboardPath), isFalse);
      expect(appShellHidesNavBar(AppRoutes.communityPath), isFalse);
      expect(appShellHidesNavBar(AppRoutes.collectionPath), isFalse);
      expect(appShellHidesNavBar(AppRoutes.morePath), isFalse);
    });

    test("'/clips'로 시작만 해서는 숨기지 않는다", () {
      // '/clipsomething' 같은 경로가 생겨도 숨기면 안 된다.
      expect(appShellHidesNavBar('/clipsomething'), isFalse);
    });
  });

  group('글쓰기 화면은 셸 밖에 둔다', () {
    /// 셸 안에 있으면 아래 탭 바가 같이 보이고, 탭을 누르면 쓰던 글이
    /// 확인 없이 사라진다(DraftPopScope는 '뒤로'만 막는다). 지금은 셸 밖
    /// 단독 라우트라 괜찮은데, 옮기면 이 테스트가 깨진다(5차).
    test('게시판·질문·투표 글쓰기가 ShellRoute 바깥에 있다', () {
      final router = buildAppRouter(seenIntro: true, userProvider: _User());
      final topPaths = <String>{
        for (final r in router.configuration.routes)
          if (r is GoRoute) r.path,
      };

      expect(topPaths, contains(AppRoutes.communityBoardWritePath));
      expect(topPaths, contains(AppRoutes.communityQuestionWritePath));
      expect(topPaths, contains(AppRoutes.communityVoteWritePath));
    });
  });
}
