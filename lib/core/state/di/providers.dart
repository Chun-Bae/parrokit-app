// ============================================================================
// lib/core/di/providers.dart
// ============================================================================
//
// [역할]
// 앱 전역 Provider 목록 정의.
// MultiProvider에서 사용할 Provider 리스트 생성.
//
// [레이어]
// Core Layer > DI
// ============================================================================

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:parrokit/core/state/provider/iap_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/ad_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/shorts_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/data/shorts_repository.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/features/community/block/data/repositories/block_repository_impl.dart';
import 'package:parrokit/features/community/block/presentation/providers/block_provider.dart';
import 'package:parrokit/features/community/notification/data/repositories/community_notification_repository_impl.dart';
import 'package:parrokit/features/community/notification/domain/usecases/delete_all_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/delete_notification_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/fetch_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/watch_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/presentation/providers/community_notification_provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_messaging_service.dart';

/// Provider 목록 생성.
///
/// 초기화된 Provider들을 받아서 전체 Provider 리스트 반환.
List<SingleChildWidget> buildProviders({
  required ThemeProvider themeProvider,
  required IapProvider iapProvider,
  required AdProvider adProvider,
  required UserProvider userProvider,
}) {
  return [
    // ─────────────────────────────────────────────────────────────────
    // 이미 초기화된 Provider들 (Value)
    // ─────────────────────────────────────────────────────────────────
    ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
    ChangeNotifierProvider<IapProvider>.value(value: iapProvider),
    ChangeNotifierProvider<AdProvider>.value(value: adProvider),

    // ─────────────────────────────────────────────────────────────────
    // 데이터베이스
    // ─────────────────────────────────────────────────────────────────
    Provider<AppDatabase>(
      create: (_) => AppDatabase(),
      dispose: (_, db) => db.close(),
    ),

    // ─────────────────────────────────────────────────────────────────
    // 사용자 관련
    // ─────────────────────────────────────────────────────────────────
    ChangeNotifierProvider<UserProvider>.value(value: userProvider),
    ChangeNotifierProvider<BlockProvider>(
      create: (c) => BlockProvider(
        BlockRepositoryImpl(FirebaseUserService()),
        c.read<UserProvider>(),
      ),
    ),

    // ─────────────────────────────────────────────────────────────────
    // 기능별 Provider들
    // ─────────────────────────────────────────────────────────────────
    ChangeNotifierProvider<ClipProvider>(
      create: (c) => ClipProvider(c.read<AppDatabase>()),
    ),
    ChangeNotifierProvider<ClipActivityProvider>(
      lazy: false,
      create: (c) => ClipActivityProvider(
        c.read<AppDatabase>(),
        c.read<ClipProvider>().service,
      ),
    ),
    ChangeNotifierProvider<ShortsProvider>(
      create: (c) => ShortsProvider(
        ShortsRepository(c.read<AppDatabase>()),
        c.read<ClipProvider>(),
      ),
    ),
    ChangeNotifierProvider<TagFilterProvider>(
      create: (c) => TagFilterProvider(c.read<AppDatabase>()),
    ),
    ChangeNotifierProxyProvider<BlockProvider, CommunityProvider>(
      create: (_) => CommunityProvider(),
      update: (_, blockProvider, communityProvider) {
        final provider = communityProvider ?? CommunityProvider();
        provider.setBlockedUserIds(blockProvider.blockedUserIds);
        return provider;
      },
    ),
    ChangeNotifierProxyProvider<UserProvider, CommunityNotificationProvider>(
      create: (_) => _createCommunityNotificationProvider(),
      update: (_, userProvider, notificationProvider) {
        final provider =
            notificationProvider ?? _createCommunityNotificationProvider();
        provider.syncUser(userProvider.currentUser?.id);
        return provider;
      },
    ),
  ];
}

/// 커뮤니티 알림 Provider를 만든다.
///
/// create와 update 양쪽에서 쓴다. update는 create 직후에 불리면서 그 인스턴스를
/// 넘겨받기 때문에 update 쪽 생성은 사실상 쓰이지 않지만, 둘 다 같은 조립을
/// 적어 두면 한쪽만 고치는 일이 생긴다. 그래서 한곳에 모았다.
CommunityNotificationProvider _createCommunityNotificationProvider() {
  return CommunityNotificationProvider(
    watchNotificationsUseCase: WatchNotificationsUseCase(
      CommunityNotificationRepositoryImpl(),
    ),
    fetchNotificationsUseCase: FetchNotificationsUseCase(
      CommunityNotificationRepositoryImpl(),
    ),
    markNotificationReadUseCase: MarkNotificationReadUseCase(
      CommunityNotificationRepositoryImpl(),
    ),
    markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(
      CommunityNotificationRepositoryImpl(),
    ),
    deleteNotificationUseCase: DeleteNotificationUseCase(
      CommunityNotificationRepositoryImpl(),
    ),
    deleteAllNotificationsUseCase: DeleteAllNotificationsUseCase(
      CommunityNotificationRepositoryImpl(),
    ),
    messagingService: FirebaseMessagingService(
      firebaseUserService: FirebaseUserService(),
    ),
  );
}
