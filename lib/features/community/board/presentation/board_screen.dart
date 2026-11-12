import 'package:flutter/material.dart';
import 'package:parrokit/features/community/shell/domain/data/community_filters.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:parrokit/features/community/shell/presentation/widgets/community_board_post_tile.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/post_list_paging.dart';

class BoardScreen extends StatefulWidget {
  final String selectedFilter;

  const BoardScreen({super.key, required this.selectedFilter});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<CommunityProvider>()
          .fetchPosts(postType: 'board', refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (provider.isLoading && provider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredPosts = provider.getBoardPostsByFilter(widget.selectedFilter);

    if (filteredPosts.isEmpty) {
      // 카테고리로 거르면 읽어 온 페이지에 맞는 글이 없을 수 있다. 더 오래된
      // 글이 남아 있으면 이어 읽을 수 있게 한다.
      final canLoadMore = provider.hasMorePosts && !provider.isLoading;
      return AppEmptyState(
        icon: Icons.forum_outlined,
        title: '등록된 게시글이 없습니다.',
        description: '첫 글을 남겨 보세요.',
        actionLabel: canLoadMore ? '이전 글 더 보기' : null,
        onAction: canLoadMore ? () => loadMorePostsFrom(context) : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context
          .read<CommunityProvider>()
          .fetchPosts(postType: 'board', refresh: true),
      child: PostListPaging(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: filteredPosts.length + 1,
          separatorBuilder: (context, index) =>
              index == filteredPosts.length - 1
                  ? const SizedBox.shrink()
                  : Divider(color: colorScheme.outlineVariant, height: 1),
          itemBuilder: (context, index) {
            if (index == filteredPosts.length) return const PostListFooter();
            return CommunityBoardPostTile(
              post: filteredPosts[index],
              showCategory:
                  widget.selectedFilter == CommunityFilters.defaultBoard,
            );
          },
        ),
      ),
    );
  }
}
