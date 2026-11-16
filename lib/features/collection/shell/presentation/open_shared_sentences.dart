// 공유된 문장을 보러 가는 길(5차 340, 사용자 요청).
//
// 전에는 따로 띄우는 '둘러보기' 화면이 있었다. 이제 커뮤니티의 문장 탭이
// 그 자리라, 보관함과 홈의 '전체 보기'는 그 탭으로 간다.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/features/community/shell/presentation/community_shell_screen.dart';

void openSharedSentences(BuildContext context) {
  CommunityShellScreen.openTab(CommunityShellScreen.sentenceTab);
  context.go(AppRoutes.communityPath);
}
