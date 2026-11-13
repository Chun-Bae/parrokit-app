import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';

/// 게시판·질문·투표 목록의 다음 페이지 읽기.
///
/// 전에는 세 목록 모두 최신 20개에서 끝났다. 스크롤이 끝에 가까워지면
/// 자동으로 이어 읽고, 목록 맨 아래에는 [PostListFooter]를 둔다.
/// 걸러 보는 목록(질문의 "답변 대기", 게시판 카테고리)은 한 페이지에
/// 맞는 글이 적어서 스크롤할 거리가 없을 수 있다. 그래서 자동 읽기만
/// 두지 않고 직접 누르는 버튼도 둔다.

/// 끝에서 이만큼 남으면 다음 페이지를 읽기 시작한다.
const double _loadMoreThreshold = 600;

/// 다음 페이지를 읽는다. 이미 읽는 중이거나 더 없으면 아무것도 하지 않는다.
///
/// [after]는 새 글이 붙은 뒤 화면이 따로 할 일(투표 상태 맞추기 등)이다.
Future<void> loadMorePostsFrom(
  BuildContext context, {
  Future<void> Function()? after,
}) async {
  final provider = context.read<CommunityProvider>();
  if (provider.isLoading || !provider.hasMorePosts) return;
  await provider.loadMorePosts();
  if (after != null) await after();
}

/// 감싼 목록이 끝에 가까워지면 다음 페이지를 읽는다.
class PostListPaging extends StatelessWidget {
  const PostListPaging({super.key, required this.child, this.onLoadedMore});

  final Widget child;
  final Future<void> Function()? onLoadedMore;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 목록 안의 가로 스크롤(사진 등)이나 더 안쪽 스크롤은 무시한다.
        if (notification.depth != 0 ||
            notification.metrics.axis != Axis.vertical) {
          return false;
        }
        if (notification.metrics.extentAfter < _loadMoreThreshold) {
          loadMorePostsFrom(context, after: onLoadedMore);
        }
        return false;
      },
      child: child,
    );
  }
}

/// 목록 맨 아래. 읽는 중이면 작은 로딩, 더 있으면 버튼, 끝이면 아무것도 없다.
class PostListFooter extends StatelessWidget {
  const PostListFooter({super.key, this.onLoadedMore});

  final Future<void> Function()? onLoadedMore;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    if (!provider.hasMorePosts) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: provider.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () =>
                    loadMorePostsFrom(context, after: onLoadedMore),
                child: const Text('이전 글 더 보기'),
              ),
      ),
    );
  }
}
