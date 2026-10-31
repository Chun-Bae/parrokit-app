// ============================================================================
// lib/core/router/app_router.dart
// ============================================================================
//
// [역할]
// GoRouter 빌더.
// 앱 라우팅 정의 및 딥링크/리다이렉트 로직 처리.
//
// [레이어]
// Core Layer > Router
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

import 'package:parrokit/features/auth/sign-in/sign_in_screen.dart';
import 'package:parrokit/features/auth/sign-up/sign_up_screen.dart';
import 'package:parrokit/features/auth/find-pw/find_pw_screen.dart';
import 'package:parrokit/features/auth/onboarding/onboarding_screen.dart';
import 'package:parrokit/features/home/dashboard/presentation/dashboard_screen.dart';
import 'package:parrokit/features/home/dashboard/presentation/character_dashboard_screen.dart';
import 'package:parrokit/features/home/dashboard/presentation/learning_hub_screen.dart';
import 'package:parrokit/features/home/dashboard/presentation/stage_preview_screen.dart';
import 'package:parrokit/features/community/shell/presentation/community_shell_screen.dart';
import 'package:parrokit/features/community/board/presentation/board_view_screen.dart';
import 'package:parrokit/features/community/board/presentation/board_write_screen.dart';
import 'package:parrokit/features/community/question/presentation/question_write_screen.dart';
import 'package:parrokit/features/community/question/presentation/question_view_screen.dart';
import 'package:parrokit/features/community/vote/presentation/vote_write_screen.dart';
import 'package:parrokit/features/community/vote/presentation/vote_view_screen.dart';
import 'package:parrokit/features/community/menu/presentation/community_menu_screen.dart';
import 'package:parrokit/features/community/block/presentation/blocked_users_screen.dart';
import 'package:parrokit/features/community/notification/presentation/community_notification_screen.dart';
import 'package:parrokit/features/community/activity/presentation/activity_screen.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/shorts_screen.dart';
import 'package:parrokit/features/collection/library/presentation/library_screen.dart';
import 'package:parrokit/features/collection/shell/presentation/collection_shell_screen.dart';
import 'package:parrokit/features/settings/more/presentation/more_screen.dart';
import 'package:parrokit/features/settings/more/presentation/storage_cache_management_screen.dart';
import 'package:parrokit/features/settings/more/presentation/profile_edit_screen.dart';
import 'package:parrokit/features/home/recent/presentation/recent_screen.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/screens/captioning_screen.dart';
import 'package:parrokit/features/collection/clip/player/presentation/clip_player_screen.dart';
import 'package:parrokit/features/content-studio/hub/presentation/content_studio_bridge_screen.dart';
import 'package:parrokit/features/content-studio/hub/presentation/content_studio_hub_screen.dart';

// Router 관련
import 'app_routes.dart';
import 'app_shell.dart';

// Re-export for convenience
export 'app_routes.dart';

/// 루트 네비게이터 키 (전역 컨텍스트 접근용)
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter 빌더.
///
/// [seenIntro]: 인트로를 봤는지 여부에 따라 초기 경로 결정.
GoRouter buildAppRouter({
  required bool seenIntro,
  required UserProvider userProvider,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.dashboardPath,
    redirect: _handleRedirect,
    refreshListenable: userProvider.routerRefreshNotifier,
    routes: [
      // ─────────────────────────────────────────────────────────────────
      // 단독 라우트 (쉘 외부)
      // ─────────────────────────────────────────────────────────────────
      _authRoute,
      GoRoute(
        path: AppRoutes.communityBoardWritePath,
        name: AppRoutes.communityBoardWrite,
        builder: (context, state) => const BoardWriteScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityQuestionWritePath,
        name: AppRoutes.communityQuestionWrite,
        builder: (context, state) => const QuestionWriteScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityVoteWritePath,
        name: AppRoutes.communityVoteWrite,
        builder: (context, state) => const VoteWriteScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityVoteViewPath,
        name: AppRoutes.communityVoteView,
        builder: (context, state) {
          final voteId = state.pathParameters['voteId'];
          if (voteId == null || voteId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text('voteId가 필요합니다.'),
              ),
            );
          }
          return VoteViewScreen(voteId: voteId);
        },
      ),
      GoRoute(
        path: AppRoutes.communityQuestionViewPath,
        name: AppRoutes.communityQuestionView,
        builder: (context, state) {
          final questionId = state.pathParameters['questionId'];
          if (questionId == null || questionId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text('questionId가 필요합니다.'),
              ),
            );
          }
          return QuestionViewScreen(questionId: questionId);
        },
      ),
      GoRoute(
        path: AppRoutes.communityMenuPath,
        name: AppRoutes.communityMenu,
        builder: (context, state) => const CommunityMenuScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityBlockedUsersPath,
        name: AppRoutes.communityBlockedUsers,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityNotificationPath,
        name: AppRoutes.communityNotification,
        builder: (context, state) => const CommunityNotificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityActivityPath,
        name: AppRoutes.communityActivity,
        builder: (context, state) {
          final boardType = state.uri.queryParameters['boardType'] ?? 'unknown';
          final activityType =
              state.uri.queryParameters['activityType'] ?? 'unknown';
          return CommunityActivityScreen(
            boardType: boardType,
            activityType: activityType,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.communityBoardViewPath,
        name: AppRoutes.communityBoardView,
        builder: (context, state) {
          final postId = state.pathParameters['postId'];
          if (postId == null || postId.isEmpty) {
            return const Scaffold(
              body: Center(
                child: Text('postId가 필요합니다. (/community/board/:postId)'),
              ),
            );
          }
          return BoardViewScreen(postId: postId);
        },
      ),
      GoRoute(
        path: AppRoutes.storageCacheManagementPath,
        name: AppRoutes.storageCacheManagement,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => const NoTransitionPage(
          name: AppRoutes.storageCacheManagement,
          child: StorageCacheManagementScreen(),
        ),
      ),

      // ─────────────────────────────────────────────────────────────────
      // Onboarding Route (소셜 로그인 후 닉네임 설정용)
      // ─────────────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ─────────────────────────────────────────────────────────────────
      // ShellRoute (하단 네비바 + 자식 화면)
      // ─────────────────────────────────────────────────────────────────
      _shellRoute,
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Redirect Handler
// ─────────────────────────────────────────────────────────────────────────────

String? _handleRedirect(BuildContext context, GoRouterState state) {
  final uri = state.uri;
  final loc = uri.toString();

  // 0) 앱 루트('/') → 대시보드로
  if (loc == '/') {
    return AppRoutes.dashboardPath;
  }

  // 2) Auth guard
  final user = Provider.of<UserProvider>(context, listen: false);
  final isOnAuth = loc.startsWith(AppRoutes.authPath);
  final isOnIntro = loc.startsWith(AppRoutes.introPath);

  if (!user.isLoggedIn && !isOnAuth && !isOnIntro) {
    return '${AppRoutes.authPath}/${AppRoutes.signInPath}';
  }

  // 3) 닉네임 체크 방어막 (로그인 상태)
  if (user.isLoggedIn) {
    final hasNickname = user.currentUser?.displayName != null &&
        user.currentUser!.displayName!.isNotEmpty;
    final isOnOnboarding = loc == AppRoutes.onboardingPath;

    // 닉네임이 없는데 온보딩 화면이 아니면 -> 강제로 온보딩 이동
    if (!hasNickname && !isOnOnboarding) {
      return AppRoutes.onboardingPath;
    }

    // 닉네임이 있는데 온보딩 화면이나 Auth 화면에 있으면 -> 대시보드로
    if (hasNickname && (isOnOnboarding || isOnAuth)) {
      return AppRoutes.dashboardPath;
    }
  }

  // Handle bare /auth redirect to /auth/sign-in
  if (loc == AppRoutes.authPath) {
    return '${AppRoutes.authPath}/${AppRoutes.signInPath}';
  }

  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Route Definitions
// ─────────────────────────────────────────────────────────────────────────────

GoRoute get _authRoute => GoRoute(
      path: AppRoutes.authPath,
      name: AppRoutes.auth,
      redirect: (context, state) {
        if (state.uri.toString() == AppRoutes.authPath) {
          return '${AppRoutes.authPath}/${AppRoutes.signInPath}';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.signInPath,
          name: AppRoutes.signIn,
          pageBuilder: (context, state) => NoTransitionPage(
            name: AppRoutes.signIn,
            child: const SignInScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.signUpPath,
          name: AppRoutes.signUp,
          pageBuilder: (context, state) => NoTransitionPage(
            name: AppRoutes.signUp,
            child: const SignUpScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.findPwPath,
          name: AppRoutes.findPw,
          pageBuilder: (context, state) => NoTransitionPage(
            name: AppRoutes.findPw,
            child: const FindPwScreen(),
          ),
        ),
      ],
    );

// ─────────────────────────────────────────────────────────────────────────────
// Shell Route (Bottom Navigation)
// ─────────────────────────────────────────────────────────────────────────────

ShellRoute get _shellRoute => ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        // Dashboard
        GoRoute(
          path: AppRoutes.dashboardPath,
          name: AppRoutes.dashboard,
          pageBuilder: (context, state) => NoTransitionPage(
            name: AppRoutes.dashboard,
            child: CharacterDashboardScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.stagePreviewPath,
          builder: (context, state) {
            final user = context.watch<UserProvider>().currentUser;
            return StagePreviewScreen(
                key: ValueKey(user?.id ?? 'guest'),
                nickname: user?.displayName ?? '나',
                accountId: user?.id ?? 'guest');
          },
        ),
        GoRoute(
          path: AppRoutes.learningHubPath,
          builder: (context, state) => const LearningHubScreen(),
        ),
        GoRoute(
          path: AppRoutes.classicDashboardPath,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),

        // Community
        GoRoute(
          path: AppRoutes.communityPath,
          name: AppRoutes.community,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.community,
            child: CommunityShellScreen(),
          ),
        ),

        // Explore (Shorts)
        GoRoute(
          path: AppRoutes.explorePath,
          name: AppRoutes.explore,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.explore,
            child: ShortsScreen(),
          ),
        ),

        // Collection Shell
        GoRoute(
          path: AppRoutes.collectionPath,
          name: AppRoutes.collection,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.collection,
            child: CollectionShellScreen(),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.collectionClipPath,
              name: AppRoutes.collectionClip,
              builder: (context, state) => LibraryScreen(
                initialCollectionId: int.tryParse(
                    state.uri.queryParameters['collectionId'] ?? ''),
                initialTab:
                    int.tryParse(state.uri.queryParameters['tab'] ?? ''),
                initialStorageMode: state.uri.queryParameters['storage'],
              ),
            ),
          ],
        ),

        // More
        GoRoute(
          path: AppRoutes.morePath,
          name: AppRoutes.more,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.more,
            child: MoreScreen(),
          ),
          routes: [
            GoRoute(
              path: AppRoutes.profileEditPath,
              name: AppRoutes.profileEdit,
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) => const ProfileEditScreen(),
            ),
          ],
        ),

        // Recents
        GoRoute(
          path: AppRoutes.recentsPath,
          name: AppRoutes.recents,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.recents,
            child: RecentScreen(),
          ),
        ),

        // Content Studio
        GoRoute(
          path: AppRoutes.contentStudioBridgePath,
          name: AppRoutes.contentStudioBridge,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.contentStudioBridge,
            child: ContentStudioBridgeScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.contentStudioHubPath,
          name: AppRoutes.contentStudioHub,
          pageBuilder: (context, state) => CustomTransitionPage(
            name: AppRoutes.contentStudioHub,
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 240),
            child: const ContentStudioHubScreen(initialIndex: 0),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final slide = Tween<Offset>(
                begin: const Offset(0.14, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              );

              return FadeTransition(
                opacity: fade,
                child: SlideTransition(position: slide, child: child),
              );
            },
          ),
        ),
        GoRoute(
          path: AppRoutes.contentStudioCaptioningPath,
          name: AppRoutes.contentStudioCaptioning,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.contentStudioCaptioning,
            child: ContentStudioHubScreen(initialIndex: 0),
          ),
        ),
        GoRoute(
          path: AppRoutes.contentStudioTtsPath,
          name: AppRoutes.contentStudioTts,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.contentStudioTts,
            child: ContentStudioHubScreen(initialIndex: 1),
          ),
        ),
        GoRoute(
          path: AppRoutes.contentStudioVideoPath,
          name: AppRoutes.contentStudioVideo,
          pageBuilder: (context, state) => const NoTransitionPage(
            name: AppRoutes.contentStudioVideo,
            child: ContentStudioHubScreen(initialIndex: 2),
          ),
        ),

        // Clips (with nested routes)
        GoRoute(
          path: AppRoutes.clipsPath,
          name: AppRoutes.clips,
          builder: (context, state) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: AppRoutes.clipsCreatePath,
              name: AppRoutes.clipsCreate,
              builder: (context, state) => CaptioningScreen(
                initialCollectionName:
                    state.uri.queryParameters['collectionName'],
              ),
            ),
            GoRoute(
              path: AppRoutes.clipsEditPath,
              name: AppRoutes.clipsEdit,
              builder: (context, state) {
                final clipIdStr = state.uri.queryParameters['clipId'];
                final clipId = int.tryParse(clipIdStr ?? '');
                return CaptioningScreen(
                  clipId: clipId,
                  initialCollectionName:
                      state.uri.queryParameters['collectionName'],
                );
              },
            ),
            GoRoute(
              path: AppRoutes.clipsPlayPath,
              name: AppRoutes.clipsPlay,
              builder: (context, state) {
                final clipIdStr = state.uri.queryParameters['clipId'];
                final clipId = int.tryParse(clipIdStr ?? '');
                if (clipId == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('clipId가 필요합니다. (?clipId=123)'),
                    ),
                  );
                }
                return ClipPlayerScreen(clipId: clipId);
              },
            ),
          ],
        ),
      ],
    );
