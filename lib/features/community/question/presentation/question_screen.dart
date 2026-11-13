import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/presentation/providers/community_provider.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/post_list_paging.dart';
import 'question_filter.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/shell/presentation/utils/community_post_ui_utils.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class QuestionScreen extends StatefulWidget {
  final String selectedFilter;

  const QuestionScreen({super.key, required this.selectedFilter});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialQuestions();
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });
    });
  }

  Future<void> _loadInitialQuestions() async {
    final provider = context.read<CommunityProvider>();

    // 다른 탭 로딩과 경합 중이면 질문 fetch가 _isLoading guard로 스킵될 수 있어
    // 질문 초기화 전용 로딩은 반드시 실제 fetch가 수행된 뒤 끝낸다.
    while (mounted && provider.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;
    await provider.fetchPosts(
      postType: 'question',
      refresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();

    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.isLoading && provider.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 질문만 골라 필터에 맞게 거르고 정렬한다(question_filter.dart).
    final questionPosts =
        questionsForFilter(provider.posts, widget.selectedFilter);

    if (questionPosts.isEmpty) {
      // "답변 대기중"·"채택 완료"는 읽어 온 페이지에서 거른 것이라, 이 페이지에
      // 맞는 질문이 없어도 더 오래된 질문에는 있을 수 있다.
      final canLoadMore = provider.hasMorePosts && !provider.isLoading;
      return AppEmptyState(
        icon: Icons.live_help_outlined,
        title: widget.selectedFilter == '전체'
            ? '아직 질문이 없어요.'
            : '해당 조건의 질문이 없습니다.',
        description: '다른 조건을 골라 보거나 직접 질문해 보세요.',
        actionLabel: canLoadMore ? '이전 글 더 보기' : null,
        onAction: canLoadMore ? () => loadMorePostsFrom(context) : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => context
          .read<CommunityProvider>()
          .fetchPosts(postType: 'question', refresh: true),
      child: PostListPaging(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 80), // Fab space
          itemCount: questionPosts.length + 1,
          separatorBuilder: (context, index) =>
              index == questionPosts.length - 1
                  ? const SizedBox.shrink()
                  : Divider(
                      color: context.tokens.disabled,
                      thickness: 8,
                    ),
          itemBuilder: (context, index) {
            if (index == questionPosts.length) return const PostListFooter();
            return GestureDetector(
              onTap: () {
                context.push(AppRoutes.communityQuestionViewPathOf(
                    questionPosts[index].id));
              },
              behavior: HitTestBehavior.opaque,
              child: _buildFeedItem(questionPosts[index], provider),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedItem(Post question, CommunityProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    final userProvider = context.watch<UserProvider>();
    final authorName = resolveCommunityAuthorName(
      post: question,
      provider: provider,
      userProvider: userProvider,
    );
    final avatarUrl = resolveCommunityAuthorAvatarUrl(
      post: question,
      provider: provider,
      userProvider: userProvider,
    );

    final isResolved = question.questionStatus == 'resolved';
    final isExpired = question.questionStatus == 'expired';

    String statusText = '답변 대기중';
    Color statusColor = context.tokens.primary;
    Color statusBgColor = context.tokens.primarySoft;

    if (isResolved) {
      statusText = '채택 완료';
      statusColor = colorScheme.onSurfaceVariant;
      statusBgColor = colorScheme.surfaceContainerHigh;
    } else if (isExpired) {
      statusText = '만료됨';
      statusColor = context.tokens.danger;
      statusBgColor = context.tokens.dangerSoft;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Author + Time + Status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Icon(Icons.person,
                              color: colorScheme.onSurfaceVariant)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  authorName,
                                  style: context.texts.bodyLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 크래커 보상 뱃지
                              if (question.rewardCrackers > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.tokens.primarySoft,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                        color: context.tokens.primary
                                            .withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🍪',
                                          style: context.texts.labelSmall),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${question.rewardCrackers}',
                                        style: context.texts.labelSmall
                                            .copyWith(
                                                color: context.tokens.primary),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            formatCommunityTimeAgo(question.createdAt),
                            style: context.texts.bodySmall
                                .copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        statusText,
                        style: context.texts.bodySmall
                            .copyWith(color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Title & Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  question.title,
                  style: context.texts.titleMedium,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  question.snippet,
                  style: context.texts.bodyMedium
                      .copyWith(color: colorScheme.onSurface),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),

              // Image Placeholder
              if (question.hasImage && question.imageUrls.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 250,
                  color: colorScheme.surfaceContainerHigh,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Image.network(
                    question.imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.image_not_supported,
                        color: colorScheme.onSurfaceVariant),
                  ),
                ),

              // Actions Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.favorite_border,
                        size: 24, color: colorScheme.onSurface),
                    const SizedBox(width: 6),
                    Text(
                      '${question.likeCount}',
                      style: context.texts.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline,
                        size: 22, color: colorScheme.onSurface),
                    const SizedBox(width: 6),
                    Text(
                      '${question.commentCount}',
                      style: context.texts.bodyMedium,
                    ),
                    const Spacer(),
                    Icon(Icons.bookmark_border,
                        size: 24, color: colorScheme.onSurface),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
